#!/usr/bin/perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
require v5.6.0;

use lib 'blib/lib';
use Net::SMS::Genie;

my $sms = Net::SMS::Genie->new(
    username    => 'awrigley',
    password    => 'warthog',
    recipient   => '07713986247',
    message     => 'hello world',
    subject     => 'foobar',
    verbose     => 1,
);

$sms->verbose( 1 );
$sms->send_sms();
