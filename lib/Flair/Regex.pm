package Flair::Regex;

# core regular exporessions

use Mojo::Base -base, -strict, -signatures;
# use Regexp::Common qw(URI);

has 'scot_external_hostname';

sub core_regex_names ($self) {
    my @list    = (qw(
        cve 
        cidr 
        ipv6_mixed 
        ipv6_suricata 
        ipv6_standard 
        ipv6_compressed 
        ipv6_cmp8colons 
        ipv4 
        uuid1 
        clsid 
        md5 
        sha1 
        sha256 
        message_id 
        email 
        lbsig 
        winregistry 
        files 
        domain_name 
        appkey 
        angle_bracket_msgid 
        jarm_hash 
        scot_uri
        internal_link
        countries
        sid
        useragent
        snumber
        suser
        snlserver1
        snlserver2
    ));
    # omitted uri on purpose, not ready for prime time
    return wantarray ? @list : \@list;
};

sub get_core_regex_array ($self) {
    my @regexes = ();
    foreach my $name ($self->core_regex_names) {
        push @regexes, $self->$name;
    }
    my @sorted = sort { $a->{re_order} <=> $b->{re_order} } @regexes;
    return wantarray ? @sorted : \@sorted;
}

sub cve ($self ) {
    return {
        name        => 'cve',
        description => 'Find CVE-YYYYMMDD references',
        regex       => qr{
            \b                  
            (CVE-(\d{4})-(\d{4,}))
            \b
        }xims,
        entity_type => 'cve',
        regex_type  => 'core',
        re_order    => 10,
        multiword   => 0,
    };
}

sub useragent ($self) {
    return {
        name        => 'useragent',
        description => 'Browser Useragent String',
        regex       => qr{
            \b
            \((?<info>.*?)\)(\s|$)|(?<name>.*?)\/(?<version>.*?)(\s|$)/gm
            \b
        }xims,
        entiry_type => 'user_agent',
        regex_type  => 'core',
        re_order    => 500,
        multiword   => 1,
    };
}



sub cidr ($self) {
    return {
        name        => 'cidr',
        description => 'Find CIDR blocks',
        regex       => qr{
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
        }xims,
        entity_type => 'cidr',
        regex_type  => 'core',
        re_order    => 20,
        multiword   => 0,
    };
}

sub ipv6_suricata ($self) {
    return {
        name        => 'ipv6_suricata',
        description => 'Find IPv6 adresses',
        regex       => qr{
            (?:
                (?:
                    (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
                )
                (?::[0-9]+)
            )
        }xims,
        entity_type => 'suricata_ipv6',
        regex_type  => 'core',
        re_order    => 31,
        multiword   => 0,
    };
}

sub ipv6_standard ($self) {
    return {
        name        => 'ipv6_standard',
        description => 'Find IPv6 adresses',
        regex       => qr{
            (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
        }xims,
        entity_type => 'ipv6',
        regex_type  => 'core',
        re_order    => 32,
        multiword   => 0,
    };
}

sub ipv6_compressed ($self) {
    return {
        name        => 'ipv6_compressed',
        description => 'Find IPv6 adresses',
        regex       => qr{
            (?= (?:[A-Z0-9]{0,4}:){0,7}[A-F0-9]{0,4}(?![:\w]) )
            ( ([0-9A-F]{1,4}:){1,7}|: )( (:[0-9A-F]{1,4}){1,7}|: )
        }xims,
        entity_type => 'ipv6',
        regex_type  => 'core',
        re_order    => 34,
        multiword   => 0,
    };
}

sub ipv6_cmp8colons ($self ) {
    return {
        name        => 'ipv6_8colons',
        description => 'Find IPv6 adresses',
        regex       => qr{
            (?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7}(?![:\w])
        }xims,
        entity_type => 'ipv6',
        regex_type  => 'core',
        re_order    => 35,
        multiword   => 0,
    };
}

sub ipv6_mixed ($self ) {
    return {
        name        => 'ipv6_mixed',
        description => 'Find IPv6 adresses',
        regex       => qr{
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
        }xims,
        entity_type => 'ipv6mixed',
        regex_type  => 'core',
        re_order    => 33,
        multiword   => 0,
    };
}

sub ipv4 ($self) {
        return {
            name        => 'ipv4',
            description => 'Find IPv4 addresses',
            regex       => qr{
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
            }xims,
            entity_type => 'ipaddr',
            regex_type  => 'core',
            re_order    => 50,
            multiword   => 0,
        };
}

sub uuid1 ($self) {
        return {
            name        => 'uuid1',
            description => 'Find UUID1s',
            regex       => qr{
                [0-9a-f]{8}
                \-
                [0-9a-f]{4}
                \-
                11[ef][0-9a-f]
                \-
                [89ab][0-9a-f]{3}
                \-
                [0-9a-f]{12}
            }xims,
            entity_type => 'uuid1',
            regex_type  => 'core',
            re_order    => 60,
            multiword   => 0,
        };
}

sub clsid ($self) {
        return {
            name        => 'clsid',
            description => 'Find CLSIDs',
            regex       => qr{
                [a-fA-F0-9]{8}
                \-
                [a-fA-F0-9]{4}
                \-
                [a-fA-F0-9]{4}
                \-
                [a-fA-F0-9]{4}
                \-
                [a-fA-F0-9]{12}
            }xims,
            entity_type => 'clsid',
            regex_type  => 'core',
            re_order    => 70,
            multiword   => 0,
        };
}

sub md5 ($self) {
    return {
        name        => 'md5',
        description => 'Find hex MD5 hashes',
        regex       => qr{
            \b
            (?!.*\@\b)([0-9a-fA-F]{32})
            \b
        }xims,
        entity_type => 'md5',
        regex_type  => 'core',
        re_order    => 80,
        multiword   => 0,
    };
}

sub sha1 ($self) {
    return {
        name        => 'sha1',
        description => 'Find hex SHA1 hashes',
        regex       => qr{
            \b
            (?!.*\@\b)([0-9a-fA-F]{40})
            \b
        }xims,
        entity_type => 'sha1',
        regex_type  => 'core',
        re_order    => 90,
        multiword   => 0,
    };
}

sub sha256 ($self) {
    return {
        name        => 'sha256',
        description => 'Find hex SHA256 hashes',
        regex       => qr{
        \b
        (?!.*\@\b)([0-9a-fA-F]{64})
        \b
        }xims,
        entity_type => 'sha256',
        regex_type  => 'core',
        re_order    => 100,
        multiword   => 0,
    };
}

sub message_id ($self) {
    return {
        name        => 'message_id',
        description => 'Find Email addresses',
        regex       => qr{
            (<|&lt;)        # starts with < or &lt;
            (?:[^\s]*?)     # some nonblank chars
            @               # an @ seperator
            (?:[^\s]*?)     # some nonblank chars
            (>|&gt;)        # ends with > or &gt;
        }xims,
        entity_type => 'message_id',
        regex_type  => 'core',
        re_order    => 109,
        multiword   => 1,
    };
}

sub email ($self) {
    return {
        name        => 'email',
        description => 'Find Email addresses',
        regex       => qr{
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
        }xims,
        entity_type => 'email',
        regex_type  => 'core',
        re_order    => 110,
        multiword   => 0,
    };
}

sub email_in_header ($self) {
    return {
        name    => 'email',
        description => 'email address from a message header',
        regex   => qr{
            \b
            (?<=".*"\ <)
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
        (?=>)
        }xims,
        entity_type => 'email',
        re_order    => 108,
        multiword   => 1,
    };
}


sub lbsig ($self) {
    return {
        name        => 'lbsig',
        description => 'Find LaikaBoss Signatures',
        regex       => qr{
        \b                                      # word boundary
        (yr:[a-z\_]+_s[0-9]+)_[0-9]+
        \b
        }xims,
        entity_type => 'lbsig',
        regex_type  => 'core',
        re_order    => 120,
        multiword   => 0,
    };
}

sub winregistry ($self) {
    return {
        name        => 'winregistry',
        description => 'Find Windows Registry Keys',
        regex       => qr{
            \b                                      # word boundary
            (
                (hklm|hkcu|hkey)[\\\w]+
            )
            \b
        }xims,
        entity_type => 'winregistry',
        regex_type  => 'core',
        re_order    => 130,
        multiword   => 0,
    };
}

sub files ($self) {
    return {
        name        => 'common_file_extensions',
        description => 'Find Filenames with common extensions',
        regex       => qr{
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
        }xims,
        entity_type => 'file',
        regex_type  => 'core',
        re_order    => 150,
        multiword   => 0,
    };
}

sub domain_name ($self) {
    return {
        name        => 'Domain_name',
        description => 'Find Domain Names',
        regex       => qr{
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
        }xims,
        entity_type => 'domain',
        regex_type  => 'core',
        re_order    => 160,
        multiword   => 0,
    };

}

sub appkey ($self) {
    return {
        name        => 'Appkey',
        description => 'Find Appkeys',
        regex       => qr{
            \b
            (
            AppKey=([0-9a-f]){28}
            )
            \b
        }xims,
        entity_type => 'appkey',
        regex_type  => 'core',
        re_order    => 170,
        multiword   => 0,
    };
}

sub angle_bracket_msgid ($self) {
    return {
        name        => 'Angle Bracket MessageId',
        description => 'Find MessageIds wrapped in <>',
        regex       => qr{
            (
            (<|&lt;)            # starts with <
            (?:[^\s]*?)         # has some non blank chars
            @                   # followed by an @
            (?:[^\s]*?)         # followed by more not blank chars
            (>|&gt;)            # ends with >
        )
        }xims,
        entity_type => '',
        regex_type  => 'core',
        re_order    => 180,
        multiword   => 0,
    };
}

sub jarm_hash ($self) {
    return {
        name        => 'jarm_hash',
        description => 'Find JARM hashes',
        regex       => qr{
            \b
            (?!.*\@\b)
            ([0-9a-fA-F]{62})
            \b
        }xims,
        entity_type => 'jarm_hash',
        regex_type  => 'core',
        re_order    => 190,
        multiword   => 0,
    };
}

sub sid ($self) {
    return {
        name        => 'sid',
        description => 'SID',
        regex       => qr{
            \b
            S-\d{1}-\d{1}-\d{2}-\d{10}-\d{10}-\d{10}-\d{3}
            \b
        }xims,
        entity_type => 'jarm_hash',
        regex_type  => 'core',
        re_order    => 190,
        multiword   => 0,
    };
}

sub snumber ($self) {
    return {
        name    => 'snumber',
        description  => 'Sandia Property Number',
        regex        => qr{
            \b
            s\d{6}\d?
            \b
        }xims,
        entity_type => 'snumber',
        regex_type  => 'core',
        re_order    => 200,
        multiword   => 0,
    };
}

sub suser ($self) {
    return {
        name    => 'suser',
        description => 'Sandia Username',
        regex       => qr{
            \b
            SANDIA\\\S+
            \b
        }xims,
        entity_type => 'suser',
        regex_type  => 'core',
        re_order    => 210,
        multiword   => 1,
    };
}

sub snlserver1 ($self) {
    return {
        name    => 'snlserver1',
        description => 'Sandia Server Name',
        regex   => qr{
            \b
            as\d+snllx
            \b
        }xims,
        entity_type => 'sandiaserver',
        regex_type  => 'core',
        re_order    => 300,
        multiword   => 0,
    };
}

sub snlserver2 ($self) {
    return {
        name    => 'snlserver2',
        description => 'Sandia Server Name',
        regex   => qr{
            \b
            as\d+mcslx
            \b
        }xims,
        entity_type => 'sandiaserver',
        regex_type  => 'core',
        re_order    => 300,
        multiword   => 0,
    };
}

# RE{URI} from REGEX::COMMON can not handle URI's with # in them
# which renders it kind of useless.
#sub uri ($self) {
#    return {
#        name        => 'uri',
#        description => 'Find URIs',
#        regex       => qr!($RE{URI})!,
#        entity_type => 'uri',
#        regex_type  => 'core',
#        re_order    => 156,
#        multiword   => 1,
#    };
#}

sub scot_uri ($self) {
    my $hostname    = $self->scot_external_hostname;
    return {
        name        => 'scot_uri',
        description => 'Find URIs to this SCOT instance and convert them to internal links',
        regex       => qr((http[s]://$hostname\/([#a-z0-9\/]*)\b))xims,
        entity_type => 'scot_uri',
        regex_type  => 'core',
        re_order    => 133,
        multiword   => 1,
    };
}

sub internal_link ($self) {
    return {
        name        => 'internal_link',
        description => 'Find internal References',
        regex       => qr{
            \b
            SCOT-
            (Alert|Alertgroup|Event|Incident|Dispatch|Intel|
             Product|VulnFeed|VulnTrack|Guid|Signature)
            -[0-9]+
            \b
        }xims,
        entity_type => 'internal_link',
        regex_type  => 'core',
        re_order    => 155,
        multiword   => 0,
    };
}

sub countries ($self) {
    my @countries = (
        'Afghanistan',
        'Albania',
        'Algeria',
        'Andorra',
        'Angola',
        'Antigua & Deps',
        'Antigua and Deps',
        'Argentina',
        'Armenia',
        'Australia',
        'Austria',
        'Azerbaijan',
        'Bahamas',
        'Bahrain',
        'Bangladesh',
        'Barbados',
        'Belarus',
        'Belgium',
        'Belize',
        'Benin',
        'Bermuda',
        'Bhutan',
        'Bolivia',
        'Bosnia Herzegovina',
        'Botswana',
        'Brazil',
        'Brunei',
        'Bulgaria',
        'Burkina',
        'Burundi',
        'Cambodia',
        'Cameroon',
        'Canada',
        'Cape Verde',
        'Central African Rep',
        'Chad',
        'Chile',
        'China',
        'Colombia',
        'Comoros',
        'Congo',
        'Democratic Republic of Congo',
        'Congo',
        'Costa Rica',
        'Croatia',
        'Cuba',
        'Cyprus',
        'Czech Republic',
        'Denmark',
        'Djibouti',
        'Dominica',
        'Dominican Republic',
        'East Timor',
        'Ecuador',
        'Egypt',
        'El Salvador',
        'Equatorial Guinea',
        'Eritrea',
        'Estonia',
        'Eswatini',
        'Ethiopia',
        'Fiji',
        'Finland',
        'France',
        'Gabon',
        'Gambia',
        'Georgia',
        'Germany',
        'Ghana',
        'Greece',
        'Grenada',
        'Guatemala',
        'Guinea',
        'Guinea-Bissau',
        'Guyana',
        'Haiti',
        'Honduras',
        'Hungary',
        'Iceland',
        'India',
        'Indonesia',
        'Iran',
        'Iraq',
        'Republic of Ireland',
        'Ireland',
        'Israel',
        'Italy',
        'Ivory Coast',
        'Jamaica',
        'Japan',
        'Jordan',
        'Kazakhstan',
        'Kenya',
        'Kiribati',
        'Korea North',
        'Korea South',
        'Kosovo',
        'Kuwait',
        'Kyrgyzstan',
        'Laos',
        'Latvia',
        'Lebanon',
        'Lesotho',
        'Liberia',
        'Libya',
        'Liechtenstein',
        'Lithuania',
        'Luxembourg',
        'Macedonia',
        'Madagascar',
        'Malawi',
        'Malaysia',
        'Maldives',
        'Mali',
        'Malta',
        'Marshall Islands',
        'Mauritania',
        'Mauritius',
        'Mexico',
        'Micronesia',
        'Moldova',
        'Monaco',
        'Mongolia',
        'Montenegro',
        'Morocco',
        'Mozambique',
        'Myanmar',
        'Namibia',
        'Nauru',
        'Nepal',
        'Netherlands',
        'New Zealand',
        'Nicaragua',
        'Niger',
        'Nigeria',
        'Norway',
        'Oman',
        'Pakistan',
        'Palau',
        'Palestine',
        'Panama',
        'Papua New Guinea',
        'Paraguay',
        'Peru',
        'Philippines',
        'Poland',
        'Portugal',
        'Qatar',
        'Romania',
        'Russian Federation',
        'Rwanda',
        'St Kitts & Nevis',
        'St Kitts and Nevis',
        'St Lucia',
        'Saint Vincent & the Grenadines',
        'Saint Vincent and the Grenadines',
        'Samoa',
        'San Marino',
        'Sao Tome & Principe',
        'Sao Tome and Principe',
        'Saudi Arabia',
        'Senegal',
        'Serbia',
        'Seychelles',
        'Sierra Leone',
        'Singapore',
        'Slovakia',
        'Slovenia',
        'Solomon Islands',
        'Somalia',
        'South Africa',
        'South Sudan',
        'Spain',
        'Sri Lanka',
        'Sudan',
        'Suriname',
        'Sweden',
        'Switzerland',
        'Syria',
        'Taiwan',
        'Tajikistan',
        'Tanzania',
        'Thailand',
        'Togo',
        'Tonga',
        'Trinidad & Tobago',
        'Trinidad and Tobago',
        'Tunisia',
        'Turkey',
        'Turkmenistan',
        'Tuvalu',
        'Uganda',
        'Ukraine',
        'United Arab Emirates',
        'United Kingdom',
        'United States',
        'Uruguay',
        'Uzbekistan',
        'Vanuatu',
        'Vatican City',
        'Venezuela',
        'Vietnam',
        'Yemen',
        'Zambia',
        'Zimbabwe',
    );
    my $rematchstr = '('.join('|', @countries).')';
    return {
        name        => 'country_name',
        description => 'Flair Country Names',
        regex       => qr{\b$rematchstr\b}ms,
        entity_type => 'country_name',
        regex_type  => 'core',
        re_order    => 500,
        multiword   => 1,
    };
}


1;

