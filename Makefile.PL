use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Net::SMS::Genie',
    'VERSION_FROM'	=> 'Genie.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        LWP::UserAgent => 1.73,
        CGI_Lite => 1.8,
        URI => 1.09,
        
    }, # e.g., Module::Name => 1.1
);
