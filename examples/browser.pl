#!/usr/bin/perl
use strict;
use warnings;
use blib;
use Config::Loader();
use File::Spec();

init();

my $prod = Config::Loader->new( get_path('config_prod') );
my $dev  = Config::Loader->new( get_path('config_dev') );
my $term = Term::ReadLine->new('Browser');

while ( defined( my $path = $term->readline("Enter path:") ) ) {
    last if $path eq 'q';
    $term->addhistory($path);
    print "\n";
    dump_vals( 'Production Config', $prod, $path );
    dump_vals( 'Dev Config',        $dev,  $path );
}

#===================================
sub dump_vals {
#===================================
    my ( $title, $config, $path ) = @_;
    print "$title\n" . ( '-' x length($title) ) . "\n  ";
    my $vals = eval { scalar $config->($path) };
    if ($@) {
        print "  -- PATH NOT FOUND  --";
    }
    else {
        if ( my $ref = ref $vals ) {
            if ( $ref eq 'ARRAY' ) {
                print "ARRAY: " . join( ', ', @$vals );
            }
            elsif ( $ref eq 'HASH' ) {
                print "HASH KEYS: " . join( ', ', keys %$vals );
            }
            else {
                print "$ref";
            }
        }
        else {
            print "SCALAR: $vals";
        }
    }
    print "\n\n";
}

#===================================
sub get_path {
#===================================
    return File::Spec->catdir(
            (  File::Spec->splitpath(
                   File::Spec->rel2abs($0)
            ))[ 0, 1 ]
            ,@_
        );
}

#===================================
sub init {
#===================================

    print <<USAGE;

    This browser allows you to compare an example configuration tree
    for production and development environments.  The only difference is
    that development has a 'local.yaml' file.

    Type in the path of the value you would like to see, eg: app.images.path
    Try just pressing Enter to start.

    'q' to quit

USAGE

    eval { require Term::ReadLine }
        or die "ERROR: "
        . "Term::ReadLine needs to be installed to use this example browser\n\n";

    eval        { require YAML::Syck }
        or eval { require YAML }
        or die "ERROR: "
        . "YAML::Syck or YAML needs to be installed to use this example browser\n\n"
        ;

}
