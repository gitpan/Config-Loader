use 5.008003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Config::Loader',
    VERSION_FROM      => 'lib/Config/Loader.pm', # finds $VERSION
    PREREQ_PM         => {
		Error             => '0.15',
		File::Spec        => '0.87',
		IO::File          => '1.10',
		Getopt::Long      => '2.34',
		Config::Find      => '0.16',
		Data::Dumper      => '2.121'
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Config/Loader.pm', # retrieve abstract from module
       AUTHOR         => 'Clinton Gormley <develop@traveljury.com>') : ()),
);

