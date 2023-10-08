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

$sql_result = $db->query("SELECT * FROM ".$db->table_name('users'));

while ($sql_result && ($sql_arr = $db->fetch_assoc($sql_result))) {

    echo "\n";
    echo "Cleaning for user " . $sql_arr['username'] . "... \n";

    $folders = unserialize($sql_arr['preferences'])['autoclean'];
    foreach( $folders as $folder => $params)
        {
            if (is_array($params)) {
                $day = $params['interval'];
                $dest = $params['destination'] == 1  ? "" : $folderTrash;
            }
            else {
                $day = $params;
                $dest = $folderTrash;
            }

            if ($day > 0)
                {
		                $string = "doveadm mailbox mutf7 -7 '".$folder."'";
                    $folderUTF7 = exec(dovecotServer($string, $dovecotServer));

                    if ($params['destination'] != 1)
                    {
                          $exec = sprintf("doveadm move -u %s %s mailbox '%s' sentbefore %sd UNFLAGGED",
                                      $sql_arr['username'],
                                      $folderTrash,
                                      $folderUTF7,
                                      $day);
                    }
                    else
                    {
                          $exec = sprintf("doveadm expunge -u %s mailbox '%s' sentbefore %sd UNFLAGGED",
                                      $sql_arr['username'],
                                      $folderUTF7,
                                      $day);
                    }

                    exec (dovecotServer($exec, $dovecotServer));
                }
        }

    if ( is_array($extraClean) && count($extraClean) > 0 )
        {
            foreach($extraClean as $folder)
               {

                  $string = "doveadm mailbox mutf7 -7 '" . $folder['folder'] . "'";
                              $folderUTF7 = exec(dovecotServer($string, $dovecotServer));

                  $exec = sprintf("doveadm expunge -u %s mailbox '%s' %s %sd %s",
                  $sql_arr['username'],
                  $folderUTF7,
                  $folder['before'],
                  $folder['days'],
                  $folder['unflagged'],
                  );

                  exec (dovecotServer($exec, $dovecotServer));
               }
        }
}

function dovecotServer(string $string, $dovecotServer)
{
	if ($dovecotServer != false)
	{
	    $string = "ssh " . $dovecotServer . " \"" . $string . "\"";
	}
	return $string;
}