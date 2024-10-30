{ regexes => [
    {
        name        => 'snumber',
        description => 'Find Sandia SNumbers',
        match       => q{
            \b
            ([sS][0-9]{6,7})
            \b
        },
        entity_type => 'snumber',
        regex_type  => 'core',
        re_order    => 100,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'cve',
        description => 'Find CVE-YYYYMMDD references',
        match       => q{
            \b                  
            (CVE-(\d{4})-(\d{4,}))
            \b
        },
        entity_type => 'cve',
        regex_type  => 'core',
        re_order    => 10,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'cidr',
        description => 'Find CIDR blocks',
        match       => q{
          \b                                      # word boundary
          (?<!\.)                                 # neg look ahead?
          (
              # first 3 octets with optional [.],{.},(.) obsfucation
              (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\(*\[*\{*\.\)*\]*\}*){3}
              # last octet
              (?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
              (/([0-9]|[1-2][0-9]|3[0-2]))   # the /32
          )
          \b
        },
        entity_type => 'cidr',
        regex_type  => 'core',
        re_order    => 20,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'ipv6',
        description => 'Find IPv6 adresses',
        match       => q{
            # first look for a suricata/snort format (ip:port)
            (?:
                # look for aaaa:bbbb:cccc:dddd:eeee:ffff:gggg:hhhh
                (?:
                    (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
                )
                # look for but dont capture a trailing :\d+
                (?=:[0-9]+)
            )
            # next try the rest of the crazy that is ipv6
            # thanks to autors of
            # https://learning.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s17.html
            |
            (?:
                # Mixed
                (?:
                    # Non-compressed
                    (?:[A-F0-9]{1,4}:){6}
                    # Compressed with at most 6 colons
                    |(?=(?:[A-F0-9]{0,4}:){0,6}
                        (?:[0-9]{1,3}\.){3}[0-9]{1,3}  # and 4 bytes
                        (?![:.\w])
                    )
                    # and at most 1 double colon
                    (([0-9A-F]{1,4}:){0,5}|:)((:[0-9A-F]{1,4}){1,5}:|:)
                    # Compressed with 7 colons and 5 numbers
                    |::(?:[A-F0-9]{1,4}:){5}
                )
                # 255.255.255.
                (?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}
                # 255
                (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])
                |
                # Standard
                (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
                |
                # Compressed with at most 7 colons
                (?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4}
                    (?![:\w])
                )  # and anchored
                # and at most 1 double colon
                (([0-9A-F]{1,4}:){1,7}|:)((:[0-9A-F]{1,4}){1,7}|:)
                |
                # Compressed with 8 colons
                (?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7}
            ) (?![:\w]) # neg lookahead to "anchor"
        },
        entity_type => 'ipv6',
        regex_type  => 'core',
        re_order    => 30,
        multiword   => 1,
        active      => 1,
    },
    {
        name        => 'ipv6_suricata',
        description => 'Find IPv6 adresses from Suricata data',
        match       => q{
          \b
          (?:
              (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
          )(?=:[0-9]+)
          \b
        },
        entity_type => 'ipv6',
        regex_type  => 'core',
        re_order    => 40,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'ipv4',
        description => 'Find IPv4 addresses',
        match       => q{
          \b                                      # word boundary
          (?<!\.)
          (
              # first 3 octets with optional [.],{.},(.) obsfucation
              (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\(*\[*\{*\.\)*\]*\}*){3}
              # last octet
              (?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
          )
          (?!\.[0-9a-zA-Z])\b
          \b
        },
        entity_type => 'ipaddr',
        regex_type  => 'core',
        re_order    => 50,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'uuid1',
        description => 'Find UUID1s',
        match       => q{
            [0-9a-f]{8}
            \-
            [0-9a-f]{4}
            \-
            11[ef][0-9a-f]
            \-
            [89ab][0-9a-f]{3}
            \-
            [0-9a-f]{12}
        },
        entity_type => 'uuid1',
        regex_type  => 'core',
        re_order    => 60,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'clsid',
        description => 'Find CLSIDs',
        match       => q{
          [a-fA-F0-9]{8}
          \-
          [a-fA-F0-9]{4}
          \-
          [a-fA-F0-9]{4}
          \-
          [a-fA-F0-9]{4}
          \-
          [a-fA-F0-9]{12}
        },
        entity_type => 'clsid',
        regex_type  => 'core',
        re_order    => 70,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'md5',
        description => 'Find hex MD5 hashes',
        match       => q{
          \b
          (?!.*\@\b)([0-9a-fA-F]{32})
          \b
        },
        entity_type => 'md5',
        regex_type  => 'core',
        re_order    => 80,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'sha1',
        description => 'Find hex SHA1 hashes',
        match       => q{
          \b
          (?!.*\@\b)([0-9a-fA-F]{40})
          \b
        },
        entity_type => 'sha1',
        regex_type  => 'core',
        re_order    => 90,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'sha256',
        description => 'Find hex SHA256 hashes',
        match       => q{
          \b
          (?!.*\@\b)([0-9a-fA-F]{64})
          \b
        },
        entity_type => 'sha256',
        regex_type  => 'core',
        re_order    => 100,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'message_id',
        description => 'Find Email addresses',
        match       => q{
                (<|&lt;)?        # optionally starts with < or &lt;
                (?:[^\s]*?)     # some nonblank chars
                @               # an @ seperator
                (?:[^\s]*?)     # some nonblank chars
                (>|&gt;)?        # optionally ends with > or &gt;
        },
        entity_type => 'message_id',
        regex_type  => 'core',
        re_order    => 111,     # must run after email
        multiword   => 1,
        active      => 1,
    },
    {
        name        => 'email',
        description => 'Find Email addresses',
        match       => q{
          \b                                      # word boundary
          (
              (?:
                  # one or more of these
                  [\=a-z0-9!#$%&'*+/?^_`{|}~-]+
                  # zero or more of these
                  (?:\.[\=a-z0-9!#$%&'*+/?^_`{|}~-]+)*
              )
              @
              (?:
                  (?!\d+\.\d+)
                  (?=.{4,255})
                  (?:
                      (?:[a-zA-Z0-9-]{1,63}(?<!-)\(*\[*\{*\.\}*\]*\)*)+
                      [a-zA-Z0-9-]{2,63}
                  )
              )
          )
          \b
        },
        entity_type => 'email',
        regex_type  => 'core',
        re_order    => 110,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'lbsig',
        description => 'Find LaikaBoss Signatures',
        match       => q{
          \b                                      # word boundary
          (yr:[a-z\_]+_s[0-9]+)_[0-9]+
          \b
        },
        entity_type => 'lbsig',
        regex_type  => 'core',
        re_order    => 120,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'winregistry',
        description => 'Find Windows Registry Keys',
        match       => q{
          \b                                      # word boundary
          (
              (hklm|hkcu|hkey)[\\\w]+
          )
          \b
        },
        entity_type => 'winregistry',
        regex_type  => 'core',
        re_order    => 130,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'common_file_extensions',
        description => 'Find Filenames with common extensions',
        match       => q{
             \b(
              [0-9a-zA-Z_\-\.]+
              \.
              (
                  7z|arg|deb|pkg|rar|rpm|tar|tgz|gz|z|zip|                  # compressed
                  aif|mid|midi|mp3|ogg|wav|wma|                             # audio
                  bin|dmg|iso|exe|bat|                                      # executables
                  csv|dat|log|mdb|sql|xml|                                  # db/data
                  eml|ost|oft|pst|vcf|                                      # email
                  apk|bat|bin|cgi|exe|jar|                                  # executable
                  fnt|fon|otf|ttf|                                          # fonts
                  ai|bmp|gif|ico|jpeg|jpg|ps|png|psd|svg|tif|tiff|          # images
                  asp|aspx|cer|cfm|css|htm|html|js|jsp|part|php|rss|xhtml|  # web serving
                  key|odp|pps|ppt|pptx|                                     # presentation
                  c|class|cpp|h|vb|swift|py|rb|                             # source code
                  ods|xls|xlsm|xlsx|                                        #spreadsheats
                  cab|cfg|cpl|dll|ini|lnk|msi|sys|                          # misc sys files
                  3g2|3gp|avi|flv|h264|m4v|mkv|mov|mp4|mpg|mpeg|vob|wmv|    # video
                  doc|docx|odt|pdf|rtf|tex|txt|wpd|                         # word processing
                  jse|jar|
                  ipt|
                  hta|
                  mht|
                  ps1|
                  sct|
                  scr|
                  vbe|vbs|
                  wsf|wsh|wsc
              )
          )\b
        },
        entity_type => 'file',
        regex_type  => 'core',
        re_order    => 150,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'Domain_name',
        description => 'Find Domain Names',
        match       => q{
            \b
            (
              (
                  (?= [a-z0-9-]{1,63} [\(\{\[]* \. [\]\}\)]*)
                  (xn--)?
                  [a-z0-9]+
                  (-[a-z0-9]+)*
                  [\(\{\[]*
                  \.
                  [\]\}\)]*
              )+
              (
                  [a-z0-9-]{2,63}
              )
              (?<=[a-z])  # prevent foo.12 from being a match
          )
          \b
        },
        entity_type => 'domain',
        regex_type  => 'core',
        re_order    => 160,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'Appkey',
        description => 'Find Appkeys',
        match       => q{
          \b
          (
          AppKey=([0-9a-f]){28}
          )
          \b
        },
        entity_type => 'appkey',
        regex_type  => 'core',
        re_order    => 170,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'Angle Bracket MessageId',
        description => 'Find MessageIds wrapped in <>',
        match       => q{
            (
              (<|&lt;)            # starts with <
              (?:[^\s]*?)         # has some non blank chars
              @                   # followed by an @
              (?:[^\s]*?)         # followed by more not blank chars
              (>|&gt;)            # ends with >
          )
        },
        entity_type => '',
        regex_type  => 'core',
        re_order    => 180,
        multiword   => 0,
        active      => 1,
    },
    {
        name        => 'jarm_hash',
        description => 'Find JARM hashes',
        match       => q{
          \b
          (?!.*\@\b)
          ([0-9a-fA-F]{62})
          \b
        },
        entity_type => 'jarm_hash',
        regex_type  => 'core',
        re_order    => 190,
        multiword   => 0,
        active      => 1,
    },
]};
