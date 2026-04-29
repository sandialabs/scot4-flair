{
  regexes => [
    {
      description => "User Defined Entity Regular Expression",
      entity_type => "supplier",
      match => q(b&apm;h photo),
      multiword => 1,
      name => "b&amp;h photo",
      re_order => 100,
      regex_type => "udef",
      re_group  => "supplier",
      active => 1,
    },
  ]
}
