#!/usr/bin/perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;

use Term::ReadKey;
use Net::SMS::Genie;

print "1..1\n";

$|++;

my %prompt = (
    username => "Enter username: ",
    password => "Enter password: ",
    recipient => "Enter recipient mobile number: ",
    message => "Enter an SMS message: ",
);

my %args;

for ( qw( username password recipient message ) )
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

$args{recipient} =~ s/\D//g;

eval {
    my $sms = Net::SMS::Genie->new( %args );
    $sms->verbose( 1 );
    $sms->send_sms();
    print STDERR 
        "You have ", 
        $sms->quota(), 
        " messages left in your monthly quota\n"
    ;
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
