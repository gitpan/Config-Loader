#!/usr/bin/perl
use strict;
use warnings;
use blib;
use File::Spec();
my $dir;

# Checks for YAML::Syck or YAML
# and finds the path for the config dir
BEGIN {
    eval        { require YAML::Syck; YAML::Syck->import(); 1 }
        or eval { require YAML;       YAML->import();       1 }
        or die "ERROR: "
        . "YAML::Syck or YAML needs to be installed to use this example browser\n\n";
    $dir = File::Spec->catdir( (
          File::Spec->splitpath( File::Spec->rel2abs($0) )
        )[ 0, 1 ],
        'config_dev'
    );

}

# Set up the class My::Config
# Normally this would happen in a startup file
use Config::Loader( 'My::Config' => $dir );

# Import the sub My::Config::C
# You'd put this line into every module which needs access to the config data
use My::Config;

my $path = shift @ARGV || '';
my $data = C($path);

print Dump($data);

