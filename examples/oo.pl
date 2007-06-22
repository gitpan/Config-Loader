#!/usr/bin/perl
use strict;
use warnings;
use blib;
use Config::Loader();
use File::Spec();

eval        { require YAML::Syck; YAML::Syck->import(); 1 }
    or eval { require YAML;       YAML->import();       1 }
    or die "ERROR: "
    . "YAML::Syck or YAML needs to be installed to use this example\n\n";

my $config = Config::Loader->new( get_path('config_dev') );
my $path = shift @ARGV || '';

my $data = $config->($path);

print Dump($data);

#===================================
sub get_path {
#===================================
    return
        File::Spec->catdir( (
            File::Spec->splitpath( File::Spec->rel2abs($0)))[ 0, 1 ],@_
        );
}

