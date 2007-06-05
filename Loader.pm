package Config::Loader;

use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';

use File::Spec();
use Storable();
use Data::Alias();
use overload (
    '&{}' => sub {
        my $self = shift;
        return sub { $self->C(@_) }
    },
    'fallback' => 1
);

use vars qw($VERSION);
$VERSION = '1.02';

=head1 NAME

Config::Loader - load a configuration directory tree containing
YAML, JSON, XML, Perl, INI or Config::General files

=head1 SYNOPSIS

   OO style
   -------------------------------------------------------
   use Config::Loader();

   my $config    = Config::Loader->new('/path/to/config');

   @hosts        = $config->('db.hosts.session');
   $hosts_ref    = $config->('db.hosts.session');
   @cloned_hosts = $config->clone('db.hosts.session');
   -------------------------------------------------------

OR

   Functional style
   -------------------------------------------------------
   # On startup
   use Config::Loader('My::Config' => '/path/to/config');


   # Then, in any module where you want to use the config
   package My::Module;
   use My::Config;

   @hosts        = C('db.hosts.sesssion');
   $hosts_ref    = C('db.hosts.sesssion');
   @cloned_hosts = My::Config::clone('db.hosts.session');
   $config       = My::Config::object;
   -------------------------------------------------------


=head1 DESCRIPTION

Config::Loader is a configuration module which has five aims:

=over

=item * Flexible storage

Store all configuration in your format(s) of choice (YAML, JSON, INI, XML, Perl,
Config::General / Apache-style config) broken down into individual files in
a configuration directory tree, for easy maintenance.
 See L</"CONFIG TREE LAYOUT">

=item * Flexible access

Provide a simple, easy to read, concise way of accessing the configuration
values (similar to L<Template>). See L</"ACCESSING CONFIG DATA">

=item * Minimal maintenance

Specify the location of the configuration files only once per
application, so that it requires minimal effort to relocate.
See L</"USING Config::Loader">

=item * Easy to alter development environment

Provide a way for overriding configuration values on a development
machine, so that differences between the dev environment and
the live environment do not get copied over accidentally.
See L</"OVERRIDING CONFIG LOCALLY">

=item * Minimise memory use

Load all config at startup so that (eg in the mod_perl environment) the
data is shared between all child processes. See L</"MINIMISING MEMORY USE">

=back

=head1 USING C<Config::Loader>

There are two ways to use C<Config::Loader>:

=over

=item OO STYLE

   use Config::Loader();
   my $config    = Config::Loader->new('/path/to/config');

   @hosts        = $config->('db.hosts.session');
   $hosts_ref    = $config->('db.hosts.session');
   @cloned_hosts = $config->clone('db.hosts.session');

=item YOUR OWN CONFIG CLASS (functional style)

The following code:

   # On startup
   use Config::Loader('My::Config' => '/path/to/config');

=over

=item *

auto-generates the class C<My::Config>

=item *

loads the configuration data in C<'/path/to/config'>

=item *

creates the subs C<My::Config::C>, C<My::Config::clone>
and C<My::Config::object>.

=back

Then when you want your application to have access to your configuration data,
you add this (eg in your class C<My::Module>):

   package My::Module;
   use My::Config;       # Note, no ()

This exports the sub C<C> into your current package, which allows you to
access your configuation data as follows:

   @hosts        = C('db.hosts.sesssion');
   $hosts_ref    = C('db.hosts.sesssion');
   @cloned_hosts = My::Config::clone('db.hosts.session');
   $config       = My::Config::object;

=back

=head1 CONFIG TREE LAYOUT

Config::Loader reads the data from any number (and type) of config files
stored in a directory tree. File names and directory names are used as keys in
the configuration hash.

It uses file extensions to decide what type of data the file contains, so:

    YAML            : .yaml .yml
    JSON            : .json .jsn
    XML             : .xml
    INI             : .ini
    Perl            : .perl .pl
    Config::General : .conf .cnf

When loading your config data, Config::Loader starts at the directory
specified at startup (see L</"USING Config::Loader">) and looks
through all the sub-directories for files ending in one of the above
extensions.

The name of the file or subdirectory is used as the first key.  So:

    global/
        db.yaml:
            username : admin
            hosts:
                     - host1
                     - host2
            password:
              host1:   password1
              host2:   password2

would be loaded as :

    $Config = {
       global => {
           db => {
               username => 'admin',
               password => { host1 => 'password1', host2 => 'password2'},
               hosts    => ['host1','host2'],
           }
       }
    }

Subdirectories are processed before the current directory, so
you can have a directory and a config file with the same name,
and the values will be merged into a single hash, so for
instance, you can have:

    confdir:
       syndication/
       --data_types/
         --traffic.yaml
         --headlines.yaml
       --data_types.ini
       syndication.conf

The config items in syndication.conf will be added to (or overwrite)
the items loaded into the syndication namespace via the subdirectory
called syndication.

=head1 OVERRIDING CONFIG LOCALLY

The situation often arises where it is necessary to specify
different config values on different machines. For instance,
the database host on a dev machine may be different from the host
on the live application.

Instead of changing this data during dev and then having to remember
to change it back before putting the new code live, we have a mechanism
for overriding config locally in a C<local.*> file and then, as long as
that file never gets uploaded to live, you are protected.

You can put a file called C<local.*> (where * is any of the recognised
extensions) in any sub-directory, and
the data in this file will be merged with the existing data.

Just make sure that the C<local.*> files are never checked into your live
code.

For instance, if we have:

    confdir:
        db.yaml
        local.yaml

and db.yaml has :

    connections:
        default_settings:
            host:       localhost
            table:      abc
            password:   123

And in local.yaml:

    db:
        connections:
            default_settings:
                password:   456

the resulting configuration will look like this:

    db:
        connections:
            default_settings:
                host:       localhost
                table:      abc
                password:   456

=head1 ACCESSING CONFIG DATA

All configuration data is loaded into a single hash, eg:

    $config = {
        db    => {
            hosts  => {
                session  => ['host1','host2','host3'],
                images   => ['host1','host2','host3'],
                etc...
            }
        }
    }


If you want to access it via standard Perl dereferences, you can just ask
for the hash:

    OO:
       $data_ref  = $config->();
       $hosts_ref = $data_ref->{db}{hosts}{session};
       $host_1    = $data_ref->{db}{hosts}{session}[0];

    Functional:
       $data_ref  = C();
       $hosts_ref = $data_ref->{db}{hosts}{session};
       $host_1    = $data_ref->{db}{hosts}{session}[0];

However, C<Config::Loader> also provides an easy to read dot-notation in the
style of Template Toolkit: C<('key1.key2.keyn')>.

A key can be the key of a hash or the index of an array. The return value is
context sensitive, so if called in list context, a hash ref or array ref will
be dereferenced.

    OO:
       @hosts     = $config->('db.hosts.session');
       $hosts_ref = $config->('db.hosts.session');
       $host_1    = $config->('db.hosts.session.0');

    Functional:
       @hosts     = C('db.hosts.session');
       $hosts_ref = C('db.hosts.session');
       $host_1    = C('db.hosts.session.0');

These lookups are memo'ised, so lookups are fast.

If the specified key is not found, then an error is thrown.

=head1 MINIMISING MEMORY USE

The more configuration data you load, the more memory you use. In order to
keep the memory use as low as possible for mod_perl (or other forking
applications), the configuration data should be loaded at startup in the
parent process.

As long as the data is never changed by the children, the configuration hash
will be stored in shared memory, rather than there being a separate copy in each
child process.

(See L<http://search.cpan.org/~pgollucci/mod_perl-2.0.3/docs/user/performance/mpm.pod>)

=head1 METHODS

=over

=item C<new()>

    $conf = Config::Loader->new($config_dir);

new() instantiates a config object, loads the config from
the directory specified, and returns the object.

=cut

#==========================================
sub new {
#==========================================
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = {};
    bless( $self, $class );

    my $dir = shift
        or die(   "Configuration directory not specified when creating a new "
                . "'$class' object" );

    if ( $dir && -d $dir && -r _ ) {

        $dir =~ s|/?$|/|;
        $self->{config_dir} = $dir;
        $self->load_config();

        return $self;
    }
    else {
        die("Configuration directory '$dir' not readable when creating a new "
                . "'$class' object" );
    }
    return $self;
}

=item C<C()>

  $val = $config->C('key1.key2.keyn');
  $val = $config->C('key1.key2.keyn',$hash_ref);

C<Config::Loader> objects are overloaded so that this also works:

  $val = $config->('key1.key2.keyn');
  $val = $config->('key1.key2.keyn',$hash_ref);

Or, if used in the functional style (see L</"USING Config::Loader">):

  $val = C('key1.key2.keyn');
  $val = C('key1.key2.keyn',$hash_ref);

C<key1> etc can be keys in a hash, or indexes of an array.

C<C('key1.key2.keyn')> returns everything from C<keyn> down,
so you can use the return value just as you would any normal Perl variable.

The return values are context-sensitive, so if called
in list context, an array ref or hash ref will be returned as lists.
Scalar values, code refs, regexes and blessed objects will always be returned
as themselves.

So for example:

  $password = C('database.main.password');
  $regex    = C('database.main.password_regex');

  @countries = C('lists.countries');
  $countries_array_ref = C('lists.countries');

  etc

If called with a hash ref as the second parameter, then that hash ref will be
examined, rather than the C<$config> data.

=cut

#==========================================
sub C {
#==========================================
    my $self = shift;
    my $path = shift;
    $path = '' unless defined $path;

    my ( $config, @keys );

    # If a private hash is passed in use that
    if (@_) {
        $config = $_[0];
        @keys   = split( /\./, $path );
        $config = $self->_walk_path( $config, 'PRIVATE', \@keys );
    }

    # Otherwise use the stored config data
    else {

        # Have we previously memoised this?
        if ( exists $self->{_memo}->{$path} ) {
            $config = Data::Alias::deref $self->{_memo}->{$path};
        }

        # Not memoised, so get it manually
        else {
            $config = $self->{config};
            (@keys) = split( /\./, $path );
            $config = $self->_walk_path( $config, '', \@keys );
            $self->{_memo}->{$path} = \$config;
        }
    }
    return wantarray
        && ref $config
        && (    ref $config eq 'HASH'
             || ref $config eq 'ARRAY' )
        ? ( Data::Alias::deref $config)
        : $config

}

#===================================
sub _walk_path {
#===================================
    my $self = shift;
    my ( $config, $key_path, $keys ) = @_;

    foreach my $key (@$keys) {
        next unless defined $key && length($key);
        if (    ref $config eq 'ARRAY'
             && $key =~ /^[0-9]+/
             && exists $config->[$key] )
        {
            $config = $config->[$key];
            $key_path .= '.' . $key;
            next;
        }
        elsif ( ref $config eq 'HASH' && exists $config->{$key} ) {
            $config = $config->{$key};
            $key_path .= ( $key_path ? '.' : '' ) . $key;
            next;
        }
        die("Invalid key '$key' specified for '$key_path'\n");
    }
    return $config;
}

=item C<clone()>

This works exactly the same way as L</"C()"> but it performs a
deep clone of the data before returning it.

This means that the returned data can be changed without
affecting the data stored in the $conf object;

The data is deep cloned, using Storable, so the bigger the data, the more
performance hit.  That said, Storable's dclone is very fast.

=cut

#==========================================
sub clone {
#==========================================
    my $self = shift;
    my $data = $self->Config::Loader::C(@_);
    return Storable::dclone($data);
}

my @Builtin_Loaders = qw(
    Config::Any::YAML
    Config::Any::General
    Config::Any::XML
    Config::Any::INI
    Config::Any::JSON
    Config::Loader::Perl
);

my %Module_For_Ext = ();
__PACKAGE__->register_loader($_) foreach @Builtin_Loaders;

=item C<register_loader()>

    Config::Loader->register_loader( 'Config::Loader::XYZ');

    Config::Loader->register_loader( 'Config::Loader::XYZ' => 'xyz','xxx');

By default, C<Config::Loader> uses the C<Config::Any>
plugins to support YAML, JSON, INI, XML, Perl and Config::General configuration
files, using the standard file extensions to recognise the file type. (See
L</"CONFIG TREE LAYOUT">).

If you would like to change the handler for an extension (eg, you want C<.conf>
and C<.cnf> files to be treated as YAML), do the following:

    Config::Loader->register_loader ('Config::Any::YAML' => 'conf', 'cnf');

If you would like to add a new config style, then your module should have two
methods: C<extensions()> (which returns a list of the extensions it handles),
and C<load()> which accepts the name of the file to load, and returns
a hash ref containing the data in the file. See L<Config::Any> for details.

Alternatively, you can specify the extensions when you load it:

    Config::Loader->register_loader ('My::Loader' => 'conf', 'cnf');

=cut

#===================================
sub register_loader {
#===================================
    my $class  = shift;
    my $loader = shift
        or die "No loader class passed to register_loader()";
    eval "require $loader"
        or die $@;
    my @extensions = @_ ? @_ : $loader->extensions;
    foreach my $ext (@extensions) {
        $Module_For_Ext{ lc($ext) } = $loader;
    }
    return;
}

=item C<load_config()>

    $config->load_config();

Will reload the config files located in the directory specified at object
creation (see L</"new()">).

BEWARE : If you are using this in a mod_perl environment, you will lose the
benefit of shared memory - each child will have its own copy of the data.
See L<MINIMISING MEMORY USE>.

Returns the config hash ref.

=cut

#==========================================
sub load_config {
#==========================================
    my $self = shift;
    return $self->{config} = $self->_load_config();
}

#==========================================
sub _load_config {
#==========================================
    my $self   = shift;
    my $dir    = shift || $self->{config_dir};
    my $config = {};
    $self->{_memo} = {};

    my @local_files;
    my @config_files
        = sort { $a cmp $b } glob( File::Spec->catfile( $dir, '*' ) );

CONFIG_FILE:
    foreach my $config_file (@config_files) {
        my ( $data, $name );
        my $filename = ( File::Spec->splitpath($config_file) )[2];

        # If it is a file
        if ( -f $config_file ) {

            # Must have an extension
            ( $name, my $ext ) = ( $filename =~ /(.+)[.]([^.]+)/ )
                or next CONFIG_FILE;

            # Must have an associated module
            my $loader = $Module_For_Ext{ lc $ext }
                or next CONFIG_FILE;

            # If it is a local file, process last
            if ( lc($name) eq 'local' ) {
                push @local_files, [ $loader, $config_file ];
                next CONFIG_FILE;
            }
            $data = $self->_load_config_file( $loader, $config_file );
        }

        # If it is a directory, recurse
        elsif ( -d $config_file ) {
            $data = $self->_load_config($config_file);
            $name = $filename;
        }

        # Anything else (eg symlink), skip
        else {
            next;
        }

        # Merge keys if already exists
        if ( exists $config->{$name} ) {
            $config->{$name}->{$_} = $data->{$_} foreach keys %$data;
        }
        else {
            $config->{$name} = $data;
        }
    }

    # Merge local config into main config
    foreach my $local_file (@local_files) {
        my $data = $self->_load_config_file(@$local_file);
        $config = $self->_merge_local( $config, $data );
    }

    return $config;
}

#==========================================
sub _merge_local {
#==========================================
    my $self   = shift;
    my $config = shift;
    my $local  = shift;
    foreach my $key ( keys %$local ) {
        if ( ref $local->{$key} eq 'HASH'
             && exists $config->{$key} )
        {
            $config->{$key}
                = $self->_merge_local( $config->{$key}, $local->{$key} );
        }
        else {
            $config->{$key} = $local->{$key};
        }
    }
    return $config;
}

#==========================================
sub _load_config_file {
#==========================================
    my $self = shift;
    my ( $loader, $config_file ) = @_;
    my $data;
    eval { $data = $loader->load($config_file) };
    if ($@) {
        die( "Error loading config file $config_file:\n\n" . $@ );
    }

    return $data;
}

=item C<clear_cache()>

    $config->clear_cache();

Config data is generally not supposed to be changed at runtime. However, if
you do make changes, you may get inconsisten results, because lookups are
cached.

For instance:

    print $config->C('db.hosts.session');  # Caches this lookup
    > "host1 host2 host3"

    $data = $config->C('db.hosts');
    $data->{session} = 123;

    print $config->C('db.hosts.session'); # uses cached value
    > "host1 host2 host3"

    $config->clear_cache();
    print $config->C('db.hosts.session'); # uses actual value
    > "123"

=cut

#===================================
sub clear_cache {
#===================================
    my $self = shift;
    $self->{_memo} = {};
    return;
}

=item C<import()>

C<import()> will normally be called automatically when you C<use Config::Loader>.
However, you may want to do this:

    use Config::Loader();
    Config::Loader->register_loader('My::Plugin' => 'ext');
    Config::Loader->import('My::Config' => '/path/to/config/dir');

If called with two params: C<$config_class> and C<$config_dir>, it
generates the new class (which inherits from Config::Loader)
specified in C<$config_class>, creates a new
object of that class and creates 4 subs:

=over

=item C<C()>

    As a function:
        C('keys...')

    is the equivalent of:
        $config->C('keys...');

=item C<clone()>

    As a function:
        clone('keys...')

    is the equivalent of:
        $config->clone('keys...');

=item C<object()>

    $config = My::Config->object();

Returns the C<$config> object,

=item C<import()>

When you use your generated config class, it exports the C<C()> sub into your
package:

    use My::Config;
    $hosts = C('db.hosts.session');

=back

=cut

#==========================================
sub import {
#==========================================
    my $caller_class = shift;
    my ( $class, $dir ) = @_;
    return
        unless defined $class;

    unless ( defined $dir ) {
        $dir   = $class;
        $class = $caller_class;
    }
    if ( $class eq __PACKAGE__ ) {
        die <<USAGE;

USAGE : use $class ('Your::Config' => '/path/to/config/dir' );

USAGE

    }

    my $inc_path = $class;
    $inc_path =~ s{::}{/}g;
    $inc_path .= '.pm';

    no strict 'refs';
    unless ( exists $INC{$inc_path} ) {
        @{ $class . '::ISA' } = ($caller_class);
        $INC{$inc_path} = 'Auto-inflated by ' . $caller_class;
    }

    my $config = $class->new($dir);

    # Export C, clone to the subclass
    *{ $class . "::C" }
        = sub { my $c = ref $_[0] ? shift : $config; return C( $c, @_ ) };
    *{ $class . "::clone" }
        = sub { my $c = ref $_[0] ? shift : $config; return clone( $c, @_ ) };
    *{ $class . "::object" } = sub { return $config };

    # Create a new import sub in the subclass
    *{ $class . "::import" } = eval '
        sub {
            my $callpkg = caller(0);
            no strict \'refs\';
            *{$callpkg."::C"} = \&' . $class . '::C;
        }';

    return;
}

=back

=head1 SEE ALSO

L<Storable>, L<Config::Any>, L<Config::Any::YAML>,
L<Config::Any::JSON>, L<Config::Any::INI>, L<Config::Any::XML>,
L<Config::Any::General>

=head1 THANKS

Thanks to Joel Bernstein and Brian Cassidy for the interface to the various
configuration modules.

=head1 TODO

Allow the merging of arrays in C<local> files - currently one array overwrites
another.  It would be nice to add/delete/change specific elements of any array.

=head1 BUGS

None known

=head1 AUTHOR

Clinton Gormley, E<lt>clinton@traveljury.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 by Clinton Gormley

=cut

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

1
