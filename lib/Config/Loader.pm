package Config::Loader;

use 5.008003;
use strict;
use warnings FATAL => 'all';
use warnings::register;
use Error qw(:try);
use File::Spec();
use IO::File();
use Getopt::Long();
use Config::Find();
use Data::Dumper;

our $VERSION = '0.01';
our %files_processed=();

our @OLDARGV;
BEGIN {
	@OLDARGV = @ARGV;
}



=head1 NAME
Config::Loader - Module to find and parse config files and to combine with command line switches.

=head1 SYNOPSIS

  use Config::Loader();
  
  my $c = Config::Loader->new (
    	config_file		=> 'name' / '/absolute/path',
    	config_dir		=> 'dir_name',
    	options			=> {
					bool				=> '!',
					incr				=> '+',
					opt_string			=> ':s',
					opt_int				=> ':i',
					opt_float			=> ':f',
					opt:extint			=> ':o',
					req_string			=> '=s',
					etc
					opt_string_array	=> ':s@',
					etc
    					}
    	cli				=> 1,
    	order			=> [qw(user global)],
    	mode			=> 'combine',
    	warn			=> 1,
    	debug			=> 0,
    	check_options	=> 1,
    	ignore_unknown	=> 1,
    };

=head1 ABSTRACT

Config::Loader finds and parses config file and combines them with command line switches (in a Getopt::Long style).

The format of data in the config files is quite flexible (but simple). All forms below are legal:

	# ignore this line

	bool1
	nobool2
	no-bool3
	bool4   =   1
	bool5   =   0
	incr1
	incr1
	incr2   =   3	
	key1	 	value1  #ignore this comment
	key2	=	value2
	key3	:	value3
	key4	=	"value 4 # include this comment"
	key5	=	"value 5 \
				include this with whitespace"\\
	array4	=	value1 value2 value3 "value 4"
	array4
	array4
	array5	=	value1, value2, value3 ,"value 4"
	array6	=	value1 \
				value2 \
					   \
				value3 \
				" value 4 "
				
	multiline_array -
	This text	#include this comment

	and more
	" just like this "
	until .
	.

	multiline_scalar -
	"This text	#ignore this comment

	and more
	\" just like this \"
	until ."
	.
				
=cut


=head1 DESCRIPTION

A list of all the methods available.  This is a completely OO module, there are no function calls.

=head2 new()

Create a new Config::Loader object - any of the parameters can be set by passing them in to the new() method. Returns the object if succesful or throws an error of type Config::Loader::Error, pointing to the line at which your script called Config::Loader.
	
=cut

#===================================
sub new {
#===================================
    my $proto = shift;
    my $class = ref ($proto) || $proto;
		
    my $self;
    $self = {
    	_config_file	=> undef,
    	_abs			=> undef,
    	_config_dir		=> undef,
    	_options		=> undef,
    	_order			=> [qw(user global)],
    	_mode			=> 'combine',
    	_warn			=> 1,
    	_debug			=> 0,
    	_check			=> 1,
    	_cli			=> 1,
    	_data			=> {},
    	_parsed			=> 0,
    	_ignore			=> 1,
    };
    bless($self,$class);
    while (my $key = shift) {
    	my $value;
		if (@_) {$value = shift} else {
			$self->throw ("Missing value for key '$key' when creating new $class object");
		}
		$self->throw ("Unknown parameter '$key' when creating new $class object") unless $self->can($key);
		$self->$key($value);
    }

    return $self;
}

=head2 parse()

After constructing the object and setting any parameters you would like to set, call

	%config_hash = $c->parse()
	$config_ref  = $c->parse()
	
This will parse the files and command line and return a hash of the read in configuration.

=cut

#===================================
sub parse {
#===================================
	my $self = shift;
	$self->throw("Options have already been parsed") if $self->parsed;
	$self->throw("No options have been set") if ($self->cli || $self->check_options) && !$self->options;
	my @files;
	push @files,$self->_process_command_line() if $self->cli;
	push @files,$self->_process_files() if $self->config_file;
#	warn "=========================================================\n";
#	warn Dumper(\@files);
	my $data = $self->_merge_options(\@files);
	$self->_set_parsed();
	return wantarray ? %$data : $data;
}

#===================================
sub parsed {
#===================================
	my $self = shift;
	return $self->{_parsed};
}

#===================================
sub _set_parsed {
#===================================
	my $self = shift;
	return $self->{_parsed}=1;
}


#===================================
sub _process_command_line {
#===================================
	my $self = shift;
	local @ARGV = @OLDARGV;
	my %args = ();
	my %options = $self->options;
	my @options = map {$_.$options{$_}} (keys %options);
	my $opt = new Getopt::Long::Parser config=>['pass_through'];
  	$opt->getoptions(
        \%args,
        @options
  	);
  	foreach my $key (keys %options) {
  		my $type = $options{$key};
  		$args{$key} = [] 
  			if $type=~/\@/ 
  				&& exists $args{$key} 
  				&& ($type=~/s/ ? $args{$key}->[0] eq '' : $args{$key}->[0] == 0);
  	}
	return \%args;
}

#===================================
sub _process_files {
#===================================
	my $self = shift;
	my @files;
	$self->_files_processed ([]);
	if ($self->absolute) {
		$files[0] = $self->_read_specific_file();
	} else {
		foreach my $file_type ($self->order) {
			my $result;
			if ($file_type eq 'user')	{
				$result = $self->_read_user_file;
			} elsif ($file_type eq 'global') {
				$result = $self->_read_global_file
			}
			push @files,$result if $result;
			last if $result && $self->mode eq 'separate';
		}			
		warnings::warn("No config files found - you should probably write one") 
			if $self->warn && !($self->files_processed);
	}
	return @files
}

#===================================
sub _read_user_file {
#===================================
	my $self = shift;
	my $file = $self->config_file;
	my $user_conf = Config::Find->find(name		=>$file,scope	=>'user') ||''; 
	my $global_conf = Config::Find->find(name	=>$file,scope	=>'global') ||'';
	$user_conf = $user_conf eq $global_conf ? '' : $user_conf;
	return undef unless $user_conf;
	return $self->_parse_file($user_conf);
}

#===================================
sub _read_global_file {
#===================================
	my $self = shift;
	my $file = $self->config_file;
	my $dir = $self->config_dir||'';
	my $global_conf;
	if ($dir) {
		$global_conf = Config::Find->find(file	=>File::Spec->catfile($dir,$file));
	}
	unless ($global_conf) {
		$global_conf = Config::Find->find(name	=>$file,scope	=>'global') ||'';
	}
	return undef unless $global_conf;
	return $self->_parse_file($global_conf);
}

#===================================
sub _read_specific_file {
#===================================
	my $self = shift;
	my $file = Config::Find->find(file=>$self->config_file) || return undef;
	return $self->_parse_file($file);
}

#===================================
sub _parse_file {
#===================================
	my $self = shift;
	my $file = shift;
	my %options = ();
	if (exists $files_processed{$file}) {
		%options = %{$files_processed{$file}}
	} else {
		my $fh = new IO::File;
		$fh->open($file) || $self->throw("Couldn't open file '$file' for reading : $@");
		my $key = '';
		my $i = 0;
		my $buffer = '';
		while (my $line = <$fh>) {
	#print "P1 : $line";
			$i++;
			#Skip blank lines or comments 
			last if $line=~/^\s*__END__\s*$/;
			next if ($line=~/^\s*\#/ || $line=~/^\s*$/);
	#print "P2\n";
			if ($line=~s/^\s*([\w\-_]+)//) {	# extract key
				$key = lc($1)
			} else {
				$self->throw("Couldn't find a key in config file '$file' in line $i : \n$line\n")
			}
	#print "P3 Key : $key\n";
			# Remove : or = or whitespace
			$line=~s/^[\s:=]*/ /;			
			
			# Check for end of line \'s
			if ($line=~s/(?<!\\)(\\\s*)$/\n/) {
	#print "P4 : Reading for end of \\ continuation\n";
				while (<$fh>) {
					$i++;
					if (s/(?<!\\)(\\\s*)$/\n/) {
						$line.=$_;
						next;
					}
					$line.=$_;
					last;
				}
			# Check for multiline indicator '-'
			} elsif ($line=~s/^\s*-\s*$//) {
	#print "P5 : Reading multiline";
				while (<$fh>) {
					$i++;
					last if /^\./;
					$line.=$_;
				}
			}
			my @terms;
			PARSE : while ($line) {
	#print "LINE : $line";		
				# Remove leading white space			
				$line=~s/^\s*//;
				# Look for text up to double quotes, space, comma or \n
				if ($line=~s/^(.*?)(?<!\\)([\"\n\s,\#])//s) {
	#print "1 : $1 : $line";
					push (@terms,"$1") if length($1);
					# If comment, remove until end of line
					if ($2 eq '#') {
	#print "2 : $2 : $line";
						$line=~s/^.*?\n//;
						last PARSE unless $line=~/\S/;
					}
					next unless $2 eq '"';
	#print "3 : $2 : $line";
					# Look for text ending double quotes
					if ($line=~s/^(.*?)(?<!\\)\"//s) {
	#print "4 : $1 : $line";
						push (@terms,"$1");
						last PARSE unless $line=~/\S/;
					} else {
						$self->throw("Open double quotes in config file '$file' at line $i");
					}
				# If line ending in \\
				} elsif ($line=~s/^(.*?\\\\)$//) {
	#print "5 : $1 : $line";
					push (@terms,"$1");
					last PARSE unless $line=~/\S/;
				} elsif ($line=~/^\s*$/s) {
	#print "6";	
					last PARSE;
				} else {
					# Couldn't find parsable text
					$self->throw("Parsing error in file '$file' line $i - unrecognised config");
				}
			}
			push @{$options{$key}},@terms;
			$line = '';
			$key = '';
		}
	}
	$self->_files_processed($file);
#	$Data::Dumper::Sortkeys = 1;
	#print Dumper(\%options);
	return $self->check_options ? $self->_check_options(\%options,$file) : $self->_rationalise_options(\%options);
}

#===================================
sub _rationalise_options {
#===================================
	# Checks for ! +, string/int/float and array vs scalar
	# Leaves required flag for _merge_options, because we don't know if a value has been supplied
	# until all values merged
	my $self = shift;
	my $options = shift;
	foreach my $key (keys %$options) {
		my @values = $options->{$key};
		next if (@values>1);
		$options->{$key} = $values[0] eq '' ? 1 : $values[0];
	}
	return $options;
}

#===================================
sub _check_options {
#===================================
	# Checks for ! +, string/int/float and array vs scalar
	# Leaves required flag for _merge_options, because we don't know if a value has been supplied
	# until all values merged
	my $self = shift;
	my $options = shift;
	my $file = shift;
	my $req = $self->options;
	foreach my $key (keys %$options) {
		# Check that the key is known
		unless (exists $req->{$key}) {
			# May be used in the negative sense ie nokey or no-key
			if ($key=~s/^(no-?)// && exists $req->{$key} && $req->{$key} eq '!') {
				delete $options->{"$1$key"};
				$options->{$key} = 0;
				next;
			} 
			unless (exists $req->{$key}) {
				if ($self->ignore_unknown) {
					delete $options->{$key};
					next;
				}
				$self->throw("Unknown option '$key' specified in $file") ;
			}
		}
		my $format = $req->{$key};
		if ($format eq '!') {
			# If no value is set, set 1, otherwise set boolean of value
			$options->{$key} = length($options->{$key}->[0]) ? 
				($options->{$key}->[0]=~/^0|n|no\s*$/i ? 0 : 1) : 0;
			next;
		}
		if ($format eq '+') {
			$options->{$key} = $options->{$key}->[0]=~/^\d+$/ ? $options->{$key}->[0] : @{$options->{$key}};
			next;
		}
		my $type = substr($format,1,1); # ie type = s/i/f/o
		if ($format=~/\@/) {
			my @values;
			foreach my $value (@{$options->{$key}}) {
				my $new_value = $self->_check_value($value,$type);
				$self->throw('Expected '.($type eq 's' ? 'string' : $type eq 'i' ? 'integer' 
						: $type eq 'o' ? 'extended integer' : 'float').
							 " for key '$key' in file '$file' but got value '$value'")
						unless defined $new_value;
				push @values,$new_value;
			}
			$options->{$key} = \@values;
		} elsif (substr($format,0,1) eq '%') {
			$self->throw("Sorry - values of type '%' are not yet implemented.");
		} else {
			my $value = join(' ',@{$options->{$key}});
#			warn Dumper($options->{$key},$value);
			my $new_value = $self->_check_value($value,$type);
			$self->throw('Expected '.($type eq 's' ? 'string' : $type eq 'i' ? 'integer' 
					: $type eq 'o' ? 'extended integer' : 'float').
						 " for key '$key' in file '$file' but got value '$value'")
					unless defined $new_value;
			$options->{$key} = $new_value;
		}
	}
	return $options;
}

#===================================
sub _merge_options {
#===================================
	my $self = shift;
	my $files = shift;
#	warn Dumper($files);
	my $data = {};
	foreach my $options (@$files) {
		foreach my $key (keys %$options) {
			next if exists $data->{$key};
			$data->{$key} = $options->{$key};
		}			
	}
	if ($self->check_options || $self->cli) {
		my $options = $self->options;
		foreach my $key (keys %$options) {
			my $type = $options->{$key};
			$self->throw ("Key '$key' is a required field") 
				if substr($type,0,1) eq '=' 
					&& !(exists $data->{$key} 
						&& ($type=~/\@/ ? @{$data->{$key}} : length($data->{$key})));
			$data->{$key} = (
				$type=~/\@/ ? []
					: $type=~/s/ ? '' : 0) unless exists $data->{$key};
		}
	}
	return $self->_set_data($data);
}

#===================================
sub _check_value {
#===================================
	my $self = shift;
	my $value = shift;
	my $type = shift;
#	warn Dumper($value,$type);
	return $value if $type eq 's';
	return 0 unless $value=~/\S/;
	return undef if $type eq 'o' && $value!~/^[-+]?[1-9][0-9]*|0x[0-9a-f]+|0b[01]+|0[0-7]$/;
	return undef if $type eq 'i' && $value!~/^[-+]?[0-9]+$/;
	return undef if $type eq 'f' && $value!~/^[-+]?[0-9.]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/;
	return $value;
}

=head2 data()

Returns the config data. You can specifiy a key to receive one value, or it returns a hash/hash-ref of all the values.

	$scalar/$ref = $c->data($key)
	$hash_ref    = $c->data
	%hash        = $c->data

=cut

#===================================
sub data {
#===================================
	my $self = shift;
	$self->throw ("Config has not yet been parsed") unless $self->parsed;
	my $key = lc(shift);
	if ($key) {
		if ($self->check_options || $self->cli) {
			$self->throw("Unknown key '$key") unless $self->options($key);
		}
		return $self->{_data}->{$key} if exists $self->{_data}->{$key};
		return undef;
	}
	return wantarray ? %{$self->{_data}} : $self->{_data};
}

#===================================
sub _set_data {
#===================================
	my $self = shift;
	my $data = shift;
	return $self->{_data} = $data;
}
	
=head2 files_processed()

Read only. Returns an array ref listing all files that were processed, in descending order or priority.

	$array_ref = $c->files_processed()

=cut

#===================================
sub files_processed {
#===================================
	my $self = shift;
	return $self->{_files_processed};
}

#===================================
sub _files_processed {
#===================================
	my $self = shift;
	my $file = shift;
	if (ref $file eq 'ARRAY') {
		$self->{_files_processed} = $file ;
	} else {
		push @{$self->{_files_processed}},$file;
	}
	return wantarray ? @{$self->{_files_processed}} : $self->{_files_processed};
}

=head2 config_file()

Use for setting which configuration file to look for.  If this value is absolute, it will look ONLY for this file.  Otherwise it searches through likely directories to find an appropriate file - uses Config::Find to these.

See order() and config_dir() for more.

=cut

#===================================
sub config_file {
#===================================
	my $self = shift;
	my $config_file = shift;
	if (defined $config_file) {
		if ($config_file) {
			$self->{_config_file} = $config_file;
			$self->{_abs} = File::Spec->file_name_is_absolute($config_file)||'';
		} else {
			$self->{_config_file} = undef;
			$self->{_abs} = undef;
		}
	}
	return $self->{_config_file};
}

=head2 absolute()

Returns true if Config::Loader reckons that the config_file you passed in is absolute. Normally you wouldn't need this, but it's available.

=cut

#===================================
sub absolute {
#===================================
	my $self = shift;
	return $self->{_abs} if defined $self->{_abs};
	$self->throw('Cannot call method absolute when config_file has not been set.');
}

=head2 config_dir()

If you have a configuration directory specific to your program (and not in the normal locations) you can specify it here.  Config::Find will find config files in (eg) /usr/local/program/conf/ if your program is being run from /usr/local/program/bin/, but it will fail if you have a symlink to your program.

=cut

#===================================
sub config_dir {
#===================================
	my $self = shift;
	my $config_dir = shift;
	if (defined $config_dir) {
		if ($config_dir) {
			$self->{_config_dir} = $config_dir;
		} else {
			$self->{_config_dir} = undef;
		}
	}
	return $self->{_config_dir};
		
}

=head2 cli()

Should Config::Loader parse the command line? True by default. If it is true, you need to provide an option list to specify what you expect to have returned to you.
	
	$c->cli(1)
	
=cut

#===================================
sub cli {
#===================================
	my $self = shift;
	my $cli = shift;
	if (defined $cli) {
		$self->{_cli} = $cli ? 1 : 0;
	}
	return $self->{_cli};
}

=head2 check_options()

Should Config::Loader check the options specified in the configuration file? If no, then just loads whatever it finds into data (trying to make sense out of it), otherwise every value is checked against the specified options.

	$c->check_options(1)

True by default

=cut

#===================================
sub check_options {
#===================================
	my $self = shift;
	my $check = shift;
	if (defined $check) {
		$self->{_check} = $check ? 1 : 0;
	}
	return $self->{_check};
}

=head2 order()

Specify the order of config files to process.  Can use 'user' and 'global'. 

'user'    - implies config files in the user's directory of the form .config_file
'global'  - looks first in the config_dir, and if nothing there, then looks in the "usual places"

If you leave out either option (or both) then those files won't be processed.

	$c->config('user','global')
	$c->config(qw [user global])

=cut

#===================================
sub order {
#===================================
	my $self = shift;
	my @order = @_;
	if (@order) {
		@order = @{$order[0]} if ref $order[0] eq 'ARRAY';
		my $i = 0;
		foreach my $option (@order) {
			$self->throw("Unrecognised order '$option'") unless $option=~/^user|global$/;
		}
		$self->{_order} = \@order;
	}
	return wantarray ? @{$self->{_order}} : $self->{_order};
}

=head2 options()

Use to specify the options (and their formats) that should be looked for.  The option formats are similar to those used in Getopt::Long.

Special formats

    '!'   : boolean, option can be specified as 'key','no-key','nokey'
	      : in config files, can also be specified as key = 1 or key = 0
	'+'   : incremental, so 'key key key' gives you key = 3
	      : in config files, can also set key = 3
	      
Normal formats take the form 'RequirementDatatypeVartype'

...where Requirement is :

	':'   : optional
	'='   : required

Datatype is :

	's'   : strings
	'i'   : integer
	'f'   : floating number
	'o'   : extended integer, perl style - see Getopt::Long for details
	
and Vartype is :

	'@'	  : array
	blank : scalar
	'%'   : Not supported
	
So a format of ':s@' would indicate an optional array of strings.

=cut
		
#===================================
sub options {
#===================================
	my $self = shift;
	return (wantarray ? %{$self->{_options}} : $self->{_options}) unless @_;
	my @options = @_;
	if (@options>1) {
		while (my $key = shift @options) {
			$key = lc($key);
			$self->throw("Option '$key' is missing value to set") unless @options;
			my $value = shift @options;
			if ($value) {
				throw ("Unrecognised value '$value' set for key '$key'") 
					unless $value=~/^(\!|\+|((=|:)[sifo](\@|\%){0,1}))$/;
				$self->{_options}->{$key} = $value;
			} else {
				delete $self->{_options}->{$key};
			}
		}
		return wantarray ? %{$self->{_options}} : $self->{_options};
	}
	my $key = $options[0];
	if ($key) {
		if (ref $key eq 'HASH') {
			return $self->{_options} = $key;
		} elsif (!ref $key) {
			return $self->{_options}->{lc($key)} if exists $self->{_options}->{lc($key)};
		}
		return undef;
	}		
	return $self->{_options} = undef;
}

=head2 mode()

Mode can be one of 'combine' or 'separate'. If 'combine' (default) then the user file and global file are merged, with the file earlier in 'order' taking precedence. If 'separate' then only the first file to be found is used.

The command line arguments are always merged and take precedence (assuming that you have not set $c->cli(0))

	$c->mode('combine')
	
=cut

#===================================
sub mode {
#===================================
	my $self = shift;
	my $mode = shift;
	if ($mode) {
		$self->throw("Unrecognised mode '$mode'") unless $mode=~/^combine|separate$/;
		$self->{_mode} = $mode;
	}
	return $self->{_mode};
}

=head2 warn() 

If no config file is found, then a warning is issued stating that no config file has been found, and that the user should probably write one.  If you set

	$c->warn(0)
	
then they do not get this message.

=cut

#===================================
sub warn {
#===================================
	my $self = shift;
	my $warn = shift;
	if (defined $warn) {
		$self->{_warn} = $warn ? 1 : 0;
	}
	return $self->{_warn};
}

=head2 debug() 

If any error occurred, then the Config::Loader object is dumped along with the error message.

	$c->debug(0)
	
is the default

=cut

#===================================
sub debug {
#===================================
	my $self = shift;
	my $debug = shift;
	if (defined $debug) {
		$self->{_debug} = $debug ? 1 : 0;
	}
	return $self->{_debug};
}

=head2 ignore_unknown()

You may have groups of config switches sitting in the same file, but for a particular part of the program, you only want a subset of switches.  If ignore_unknown is set to true, then any unknown switches are ignored.  Otherwise, it throws an error.

This only applies if check_options is set to true. Otherwise, all options set in config files are included.

=cut

#===================================
sub ignore_unknown {
#===================================
	my $self = shift;
	my $ignore = shift;
	if (defined $ignore) {
		$self->{_ignore} = $ignore ? 1 : 0;
	}
	return $self->{_ignore};
}

#===================================
sub throw {
#===================================
	my $self = shift;
	my $error = shift;
	my $i = 0;
	while (my @caller = caller($i++)) {
		last if $caller[0] ne __PACKAGE__;
	}
	local $Error::Depth = $i;
	throw Config::Loader::Error (-text => $error,$self->debug ? (-object=>$self) : ());
}

#===================================
#===================================
package Config::Loader::Error;
#===================================
#===================================

use base qw(Error);
use Data::Dumper;

#===================================
sub stringify {
#===================================
	my $error = shift;
	return $error->text.' at '.$error->file.' line '.$error->line."\n".
		($error->object ? Dumper($error->object): '');
}

=head1 EXPORT

None by default.

=head1 TODO

Add parsing to recognise hash style lists
Write tests

=head1 KNOWN BUGS

None, but please let me know

=head1 SEE ALSO

Config::Find

=head1 AUTHOR

Clinton Gormley, E<lt>develop@traveljury.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Clinton Gormley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut


1
