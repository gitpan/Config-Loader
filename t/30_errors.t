use strict;
use warnings;

use File::Spec;
#use Test::More 'tests' => 8;
use Test::More 'no_plan';

BEGIN { use_ok('Config::Loader'); }

my $config;

eval { $config = Config::Loader->new()};
like(       $@,
            qr/Configuration directory not specified/,
            'New - no directory' );

eval { $config = Config::Loader->new(get_path('none'))};
like(       $@,
            qr/not readable/,
            'New - directory not readable' );

eval { $config = Config::Loader->new(get_path('bad'))};
like(       $@,
            qr/Error loading config/,
            'New - Error loading config' );

$config = Config::Loader->new(get_path('perl'));
eval { $config->('global.nonexistent')};
like(       $@,
            qr/Invalid key/,
            'Invalid key' );

eval {Config::Loader->register_loader()};
like(       $@,
            qr/No loader class/,
            'No loader class' );

eval {Config::Loader->register_loader('Config::Loader::None')};
like(       $@,
            qr{Can't locate Config/Loader/None.pm},
            'Bad loader class' );

eval {Config::Loader->import(get_path('perl'))};
like(       $@,
            qr{USAGE},
            'Bad import' );

eval { $config = Config::Loader->new(path => get_path('perl'), load_as => sub {return ''})};
like(       $@,
            qr/load_as\(\) cannot return ''/,
            "New - main load_as '' " );

eval { $config = Config::Loader->new(path => get_path('errors','array_merge'))};
like(       $@,
            qr/Array override for key/,
            "Array override" );

eval { $config = Config::Loader->new(path => get_path('errors','array_delete_ref'))};
like(       $@,
            qr/Index delete.*array ref/,
            "Array delete ref" );

ok ($config = Config::Loader->new(path => get_path('errors','array_delete_int')),
            'Array delete int'
    );

eval { $config = Config::Loader->new(path => get_path('errors','array_insert_ref'))};
like(       $@,
            qr/Array add .*ref/,
            "Array insert ref" );

ok ($config = Config::Loader->new(path => get_path('errors','array_insert_int')),
            'Array insert int'
    );

eval { $config = Config::Loader->new(path => get_path('empty'), load_as =>{})};
like(       $@,
            qr/load_as\(\) cannot be a hashref/,
            "Load_as hash ref" );

eval { $config = Config::Loader->new(path => get_path('empty'), load_as => [])};
like(       $@,
            qr/single regex/,
            "Load_as array ref" );

eval { $config = Config::Loader->new(path => get_path('empty'), is_local => 'abc')};
like(       $@,
            qr/not a regular expression/,
            "Not regex" );



sub get_path {
    return File::Spec->catdir(
            (  File::Spec->splitpath(
                   File::Spec->rel2abs($0)
            ))[ 0, 1 ]
            , 'data',@_
        );
}
