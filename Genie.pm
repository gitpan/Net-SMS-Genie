package Net::SMS::Genie;

use strict;

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

require LWP::UserAgent;
use CGI_Lite;
use URI;
use Carp;

#------------------------------------------------------------------------------
#
# POD
#
#------------------------------------------------------------------------------

=head1 NAME

Net::SMS::Genie - a module to send SMS messages using the Genie web2sms
gateway (htto://www.genie.co.uk/).

=head1 SYNOPSIS

    my $sms = Net::SMS->new(
        username => 'yourname',
        password => 'yourpassword',
        recipient => 07713123456,
        subject => 'a test',
        message => 'a test message',
    );

    $sms->verbose( 1 );
    $sms->message( 'a different message' );
    print "sending message to mobile number ", $sms->recipient();

    $sms->send();

=head1 DESCRIPTION

A perl module to send SMS messages, using the Genie web2sms gateway. This
module will only work with mobile phone numbers that have been registered with
Genie (http://www.genie.co.uk/) and uses form submission to a URL that may be
subject to change.

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# Package globals
#
#------------------------------------------------------------------------------

use vars qw($VERSION $BASE_URL $SEND_URL %REQUIRED_KEYS %LEGAL_KEYS $MAX_CHARS);
$VERSION = '0.006';
$BASE_URL = 'http://www.genie.co.uk';
$SEND_URL = "$BASE_URL/gmail/sms";
my $LOGIN_URL = "$BASE_URL/login/doLogin";
my $PROFILE_URL = "$BASE_URL/userprofile/userprofile.html";
%REQUIRED_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    subject => 1,
    message => 1,
);
%LEGAL_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    subject => 1,
    message => 1,
    verbose => 1,
);
$MAX_CHARS = 123;

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my %params = @_;

    my $self = bless \%params, $class;
    $self->{COOKIES} = [];

    return $self;
}

#------------------------------------------------------------------------------
#
# AUTOLOAD - to set / get object attributes
#
#------------------------------------------------------------------------------

sub AUTOLOAD
{
    my $self = shift;
    my $value = shift;

    use vars qw( $AUTOLOAD );
    my $key = $AUTOLOAD;
    $key =~ s/.*:://;
    return if $key eq 'DESTROY';
    confess ref($self), ": unknown method $AUTOLOAD\n" unless $LEGAL_KEYS{ $key };
    if ( defined( $value ) )
    {
        $self->{$key} = $value;
    }
    return $self->{$key};
}

sub get
{
    my $self = shift;
    my $url = shift;
    my %headers = @_;

    my $request = HTTP::Request->new( 'GET', $url );
    # bug fix kindly provided by Joel Hughes <joel.hughes@eyestorm.com>
    $request->header( 'Accept' => 'text/html' );
    $request->header( 'Cookie' => join( ';', @{$self->{COOKIES}} ) )
        if @{$self->{COOKIES}}
    ;
    print STDERR $request->as_string() if $self->verbose();
    my $ua = LWP::UserAgent->new;
    $ua->agent( "Mozilla/4.0 (compatible; MSIE 4.01; Windows NT)" );
    $self->{RESPONSE} = $ua->simple_request( $request );
    print STDERR $self->{RESPONSE}->headers_as_string() if $self->verbose();
    if ( $self->{RESPONSE}->is_error )
    {
        confess
            ref($self), ": ", $request->uri,
            " failed:\n\t", 
            $self->{RESPONSE}->status_line, 
            "\n"
        ;
    }
    $self->get_cookies();
    my $location = $self->get_location();
    if ( $location )
    {
        return $self->get( URI->new_abs( $location, $BASE_URL ) );
    }
}

sub get_cookies
{
    my $self = shift;

    push(
        @{$self->{COOKIES}},
        reverse grep s{;.*}{}, $self->{RESPONSE}->header( 'Set-Cookie' )
    );
}

sub get_location
{
    my $self = shift;

    return $self->{RESPONSE}->header( 'Location' );
}

sub get_url
{
    my $url = shift;
    my %params = @_;

    return "$url?" .
        join '&', 
        map { url_encode( $_ . "=$params{$_}" ) } keys %params
    ;
}

sub send
{
    my $self = shift;

    for ( keys %REQUIRED_KEYS )
    {
        confess ref($self), ": $_ field is required\n" unless $self->{$_};
    }
    my $message_length = 
        length( $self->{subject} ) + length( $self->{message} )
    ;
    if ( $message_length > $MAX_CHARS )
    {
        confess ref($self), 
            ": total message length (subject + message)  is too long ",
            "(> $MAX_CHARS)\n"
        ;
    }
    my %send = (
        RECIPIENT => $self->{recipient},
        SUBJECT => $self->{subject},
        MESSAGE => $self->{message},
        check => 0,
        left => $MAX_CHARS - $message_length,
        action => 'Send',
    );
    my %login = (
        username => $self->{username},
        password => $self->{password},
        numTries => '',
    );
    my $send_url = get_url( $SEND_URL, %send );
    my $login_url = get_url( $LOGIN_URL, %login );
    $self->get( $login_url );
    $self->get( $send_url );
}

1;
