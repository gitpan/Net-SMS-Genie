#!/usr/bin/perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
require v5.6.0;

use Term::ReadKey;
use Net::SMS::Genie;

print "1..1\n";

$|++;

my %prompt = (
    username => "Enter Genie username: ",
    password => "Enter Genie password: ",
    recipient => "Enter recipient mobile number: ",
    subject => "Enter an SMS subject: ",
    message => "Enter an SMS message: ",
);

my %args;

for ( qw( username password recipient subject message ) )
{
    ReadMode 'noecho' if $_ eq 'password';
    print $prompt{$_}; 
    chomp( my $response = <> );
    $args{$_} = $response;
    if ( $_ eq 'password' )
    {
        print "\n";
        ReadMode 'normal';
    }
}

eval {
    my $sms = Net::SMS::Genie->new( %args );
    $sms->verbose( 1 );
    $sms->send();
};

if ( $@ )
{
    print "error: $@\n";
    print "NOT ok 1\n";
}
else
{
    print "ok 1\n";
}
