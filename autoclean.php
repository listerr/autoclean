<?php

/**
* Auto Clean
*
*
*
* @version 1.0
* @author Wojciech Bielec
* @url http://roundcube.net/plugins/autoclean
*/

class autoclean extends rcube_plugin
{
    private $rc;
    private $config;

    function init()
    {
        $this->rc = rcube::get_instance();
        $this->load_config();

        $this->add_texts('localization/', true);

        if ($this->rc->task === 'settings') {

            $this->add_hook('folder_form', array($this, 'settingAutoclean'));
            $this->add_hook('folder_update', array($this, 'saveAutoclean'));
        }
    }

    public function saveAutoclean()
    {
        if (isset($_POST['_autocleanmode']) )
        {
            $ac_folders = $this->rc->config->get('autoclean');
            $ac_folders[ $_POST['_mbox'] ] = [
                                               'interval'      => (int) $_POST['_autocleanmode'],
                                               'destination'   => (int)$_POST['_autocleandest']
                                             ];

            $this->rc->user->save_prefs(array('autoclean' => $ac_folders));

        }

        return null ;
    }

    public function settingAutoclean($args)
    {
        $this->add_texts('localization/', false);
        $config = $this->rc->config->get('autoclean');
        if (isset($config[$args['options']['name']])) {
            if (is_array($config[$args['options']['name']])) {
                $value = $config[$args['options']['name']]['interval'];
                $dest = $config[$args['options']['name']]['destination'];
            }
            else {
                $value = $config[$args['options']['name']];
            }
        }
        else {
            $value = "";
        }

        $header_select = new html_select(array('name' => '_autocleanmode', 'class' => 'form-control custom-select pretty-select'));
        $header_select->add('---', '');

        $days = $this->rc->config->get('autoclean_interval', true);

        foreach ($days as $index)
        {
            $after = "ac_after".$index;
            if ( !preg_match( '/\[ac\_/' , $this->gettext($after) )) {
                $text = $this->gettext($after);
            } else {
                $text = sprintf($this->gettext('ac_afterN'),$index);
            }

            $header_select->add($text,$index);
        }

        $autocleanmode = [
            'label' => $this->gettext('ac_title').$args['options']['mbox'],
            'value' => html::div('', $header_select->show($value)),
            ]
        ;

        $dest_select = new html_select(array('name' => '_autocleandest', 'class' => 'form-control custom-select pretty-select'));
        $dest_select->add($this->gettext('ac_destTrash'),0);
        $dest_select->add($this->gettext('ac_destRemove'),1);

        $autocleandest = [
            'label' => $this->gettext('ac_titleDest'),
            'value' => html::div('', $dest_select->show($dest)),
        ]
        ;

        $args['form']['props']['fieldsets']['settings']['content']['autocleanmode'] = $autocleanmode;
        $args['form']['props']['fieldsets']['settings']['content']['autocleandest'] = $autocleandest;

        return $args;
    }

}