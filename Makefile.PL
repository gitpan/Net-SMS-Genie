use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Net::SMS::Genie',
    'VERSION_FROM'	=> 'Genie.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        Net::SMS::Web   => undef,
        Carp            => undef,
    }, # e.g., Module::Name => 1.1
);
