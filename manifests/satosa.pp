require stdlib

class sunet::satosa() {
   $proxy_conf = hiera("satosa_proxy_conf")
   $default_conf = { 
      STATE_ENCRYPTION_KEY       => hiera("satosa_state_encryption_key"),
      USER_ID_HASH_SALT          => hiera("satosa_user_id_hash_salt"),
      CUSTOM_PLUGIN_MODULE_PATHS => ["plugins"],
      COOKIE_STATE_NAME          => "SATOSA_STATE"
   }
   $merged_conf = merge($proxy_conf,$default_conf)
   ensure_resource('file','/etc', { ensure => directory } )
   ensure_resource('file','/etc/satosa', { ensure => directory } )
   ensure_resource('file',"/etc/satosa/", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/run", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/plugins", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/metadata", { ensure => directory } )
   ["backend","frontend","https","metadata"].each |$id| {
      sunet::snippets::keygen {"$name_$id_keygen":
         key_file  => "/etc/satosa/$id.key",
         cert_file => "/etc/satosa/$id.crt"
      }
   }
   file {"/etc/satosa/proxy_conf.yaml":
      content => inline_template("<%= @merged_conf.to_yaml %>\n")
   }
   $plugins = hiera("satosa-config")
   sort(keys($plugins)).each |$n| {
      $conf = hiera($n)
      file { "$plugins[$n]":
         content => inline_template("<%= @conf.to_yaml %>\n")
      }
   }
}
