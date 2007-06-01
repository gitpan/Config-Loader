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

## Unless they have a version of Config::Loader >=1, refer them to backpan
eval { require Config::Loader };
unless ( $Config::Loader::VERSION >= 1 ) {
    prompt <<WARNING;
        
*** WARNING ***

Config::Loader has changed completely between version 0.01
and version 1.00. If this version is not what you are expecting,
you can find the old Config::Loader on http://backpan.cpan.org.

Press ENTER to continue installing:
WARNING

}

## Optional modules
my $cpan = $INC{'CPAN.pm'} || $INC{'CPANPLUS.pm'};

print "OPTIONAL MODULES:\n" . ( '-' x 17 ) . "\n";
OPTION: foreach my $optional (@optional) {
    foreach my $module (@$optional) {
        printf( "  - %-20s : ", $module );
        eval "require $module";
        if ($@) {
            if ($cpan) {    
                if ( lc( prompt( "Install : [y/N]", 'n' ) ) eq 'y' ) {
                    $prereqs{$module} = 0;
                    next OPTION;
                }
            }
            else {
                print "NOT installed\n";
            }
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

