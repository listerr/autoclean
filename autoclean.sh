#!/usr/bin/env php
<?php
/*
 +-----------------------------------------------------------------------+
 | autoclean.sh                                                          |
 |                                                                       |
 | Licensed under the GNU General Public License version 3               |
 |                                                                       |
 +-----------------------------------------------------------------------+
 | Author: Wojciech Bielec dev@bielec.nat                                |
 +-----------------------------------------------------------------------+
*/

define('INSTALL_PATH', realpath(dirname(__FILE__) . '/../..') . '/' );

require_once INSTALL_PATH.'program/include/clisetup.php';

ini_set('memory_limit', -1);

// connect to DB
$rcmail = rcmail::get_instance();

$db = $rcmail->get_dbh();
$db->db_connect('w');

if (!$db->is_connected() || $db->is_error())
    die("No DB connection\n");

$rcmail->config->load_from_file(dirname(__FILE__) . '/config.inc.php.dist');
$rcmail->config->load_from_file(dirname(__FILE__) . '/config.inc.php');

$extraClean = $rcmail->config->get('autoclean_extra_clean', null);
$folderTrash = $rcmail->config->get('autoclean_trash_folder', 'Trash');
$dovecotServer = $rcmail->config->get('autoclean_dovecot_server', false);
$dovecotApiUrl = $rcmail->config->get('autoclean_dovecot_api_url', null);
$dovecotApiKey = $rcmail->config->get('autoclean_dovecot_api_key', null);

$useDovecotApi = !empty($dovecotApiUrl) || !empty($dovecotApiKey);
if ($useDovecotApi && (empty($dovecotApiUrl) || empty($dovecotApiKey))) {
    throw new RuntimeException(
        'Both autoclean_dovecot_api_url and autoclean_dovecot_api_key must be configured'
    );
}

$sql_result = $db->query("SELECT * FROM ".$db->table_name('users'));

while ($sql_result && ($sql_arr = $db->fetch_assoc($sql_result))) {
    echo "\n";
    echo "Cleaning for user " . $sql_arr['username'] . "... \n";

    $commands = [];
    $preferences = unserialize($sql_arr['preferences']);
    $folders = $preferences['autoclean'] ?? [];

    foreach ($folders as $folder => $params) {
        if (is_array($params)) {
            $day = $params['interval'];
            $expunge = $params['destination'] == 1;
        } else {
            $day = $params;
            $expunge = false;
        }

        if ($day <= 0) {
            continue;
        }

        if ($useDovecotApi) {
            $arguments = [
                'user' => $sql_arr['username'],
                'query' => [
                    'mailbox',
                    mailboxToUtf8($folder),
                    'sentbefore',
                    $day . 'd',
                    'unflagged',
                ],
            ];
            $command = $expunge ? 'expunge' : 'move';
            if ($command === 'move') {
                $arguments['destinationMailbox'] = mailboxToUtf8($folderTrash);
            }
            $commands[] = [$command, $arguments, 'clean-' . count($commands)];
            continue;
        }

        $string = "doveadm mailbox mutf7 -7 '" . $folder . "'";
        $folderUTF7 = exec(dovecotServer($string, $dovecotServer));

        if (!$expunge) {
            $exec = sprintf(
                "doveadm move -u %s %s mailbox '%s' sentbefore %sd UNFLAGGED",
                $sql_arr['username'],
                $folderTrash,
                $folderUTF7,
                $day
            );
        } else {
            $exec = sprintf(
                "doveadm expunge -u %s mailbox '%s' sentbefore %sd UNFLAGGED",
                $sql_arr['username'],
                $folderUTF7,
                $day
            );
        }

        exec(dovecotServer($exec, $dovecotServer));
    }

    if (is_array($extraClean) && count($extraClean) > 0) {
        foreach ($extraClean as $folder) {
            if ($useDovecotApi) {
                $query = [
                    'mailbox',
                    mailboxToUtf8($folder['folder']),
                    $folder['before'],
                    $folder['days'] . 'd',
                ];
                $unflagged = trim($folder['unflagged']);
                if ($unflagged === 'unflagged') {
                    $query[] = 'unflagged';
                } elseif ($unflagged !== '') {
                    throw new RuntimeException('Unexpected unflagged filter');
                }
                $commands[] = [
                    'expunge',
                    [
                        'user' => $sql_arr['username'],
                        'query' => $query,
                    ],
                    'clean-' . count($commands),
                ];
                continue;
            }

            $string = "doveadm mailbox mutf7 -7 '" . $folder['folder'] . "'";
            $folderUTF7 = exec(dovecotServer($string, $dovecotServer));

            $exec = sprintf(
                "doveadm expunge -u %s mailbox '%s' %s %sd %s",
                $sql_arr['username'],
                $folderUTF7,
                $folder['before'],
                $folder['days'],
                $folder['unflagged']
            );

            exec(dovecotServer($exec, $dovecotServer));
        }
    }

    if ($useDovecotApi && count($commands) > 0) {
        runDovecotApiCommands($dovecotApiUrl, $dovecotApiKey, $commands);
    }
}

function mailboxToUtf8(string $mailbox): string
{
    if (!function_exists('mb_convert_encoding')) {
        throw new RuntimeException('The PHP mbstring extension is required for the Dovecot HTTP API');
    }

    return mb_convert_encoding($mailbox, 'UTF-8', 'UTF7-IMAP');
}

function runDovecotApiCommands(string $url, string $apiKey, array $commands): void
{
    if (!function_exists('curl_init')) {
        throw new RuntimeException('The PHP curl extension is required for the Dovecot HTTP API');
    }

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: X-Dovecot-API ' . base64_encode($apiKey),
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($commands, JSON_THROW_ON_ERROR),
    ]);

    $response = curl_exec($ch);
    if ($response === false) {
        $error = curl_error($ch);
        curl_close($ch);
        throw new RuntimeException('Doveadm HTTP request failed: ' . $error);
    }

    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($status !== 200) {
        throw new RuntimeException("Doveadm HTTP $status: $response");
    }

    $results = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    foreach ($results as $result) {
        if (($result[0] ?? null) !== 'doveadmResponse') {
            throw new RuntimeException(
                'Doveadm command failed: ' . json_encode($result, JSON_THROW_ON_ERROR)
            );
        }
    }
}

function dovecotServer(string $string, $dovecotServer)
{
    if ($dovecotServer != false) {
        $string = "ssh " . $dovecotServer . " \"" . $string . "\"";
    }
    return $string;
}
