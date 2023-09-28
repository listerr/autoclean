<?php

/*
 +-----------------------------------------------------------------------+
 | Local configuration for the Plugin autoclean                          |
 |                                                                       |
 +-----------------------------------------------------------------------+
*/


// Day interval array
$config['autoclean_interval'] = [3,7,14,21,30,60,90,180,365,730,1826];

// System folder Trash - default: Trash
$config['autoclean_trash_folder'] = 'Trash';

// A real server running dovecot. Access to the dovadm application is required.
// The connection is made using ssh. 
// If dovecot is on the same server as roundcube, set parameter as null.
$config['autoclean_dovecot_server'] = '192.168.0.4';

// extra cleaning command, performed for ALL users
$config['autoclean_extra_clean'] =
    [
	    // delete mails older than 60 days from Spam folder
	[
	    'folder' => 'Spam',       // folder name
	    'days' => '60',           // number of days
	    'before' => 'sentbefore', // 'sentbefore' or 'savebefore'
	    'unflagged' => '',        // 'unflagged' or empty
	],
        // delete trash e-mails older than 2 year (730 days)
	[
	    'folder' => 'Trash',
	    'days' => '730',
	    'before' => 'savebefore',
	    'unflagged' => 'unflagged',
	]
    ];

