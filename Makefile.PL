use ExtUtils::MakeMaker;

my %prereqs = ( 'Test::More'  => 0,
                'File::Spec'  => 0,
                'Storable'    => 0,
                'Data::Alias' => '1.01',
                'Config::Any' => '0.07',
);

my @optional = ( [ 'YAML::Syck', 'YAML' ],
                 [ 'JSON::Syck', 'JSON' ],
                 ['Config::Tiny'], ['XML::Simple'], ['Config::General']
);

prompt <<WARNING;
        
*** WARNING ***

Config::Loader has been deprecated in favour of Config::Merge, which is
a more meaningful name.  All new development will happen in Config::Merge.

Press ENTER to continue installing.

WARNING

## Optional modules

print "OPTIONAL MODULES:\n" . ( '-' x 17 ) . "\n";
OPTION: foreach my $optional (@optional) {
    foreach my $module (@$optional) {
        printf( "  - %-20s : ", $module );
        eval "require $module";
        if ($@) {
            if ( lc( prompt( "Install : [y/N]", 'n' ) ) eq 'y' ) {
                $prereqs{$module} = 0;
            }
            next OPTION;
        }
        else {
            print "Installed\n";
            next OPTION;
        }
    }
}

WriteMakefile( 'NAME'          => 'Config::Loader',
               'VERSION_FROM'  => 'Loader.pm',
               'ABSTRACT_FROM' => 'Loader.pm',
               'PREREQ_PM'     => \%prereqs,
               'AUTHOR'        => ' Clinton Gormley <clint@traveljury.com>',
               $ExtUtils::MakeMaker::VERSION >= 6.31
               ? ( 'LICENSE' => 'perl' )
               : (),
);

