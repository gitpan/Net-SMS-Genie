package Net::SMS::Genie;

use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

require LWP::UserAgent;
use CGI_Lite;
use URI;

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

=cut

#------------------------------------------------------------------------------
#
# Package globals
#
#------------------------------------------------------------------------------

our $VERSION = '0.001';
our $BASE_URL = 'http://www.genie.co.uk';
our $SEND_URL = "$BASE_URL/gmail/sms";
my $LOGIN_URL = "$BASE_URL/login/doLogin";
my $PROFILE_URL = "$BASE_URL/userprofile/userprofile.html";
our %REQUIRED_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    subject => 1,
    message => 1,
);
our %LEGAL_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    subject => 1,
    message => 1,
    verbose => 1,
);
our $MAX_CHARS = 123;

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
    die ref($self), ": unknown method $AUTOLOAD\n" unless $LEGAL_KEYS{ $key };
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
    $request->header( 'Cookie' => join( ';', @{$self->{COOKIES}} ) ) 
        if @{$self->{COOKIES}}
    ;
    my $ua = LWP::UserAgent->new;
    $ua->agent( "Mozilla/4.0 (compatible; MSIE 4.01; Windows NT)" );
    print STDERR $request->as_string() if $self->verbose();
    $self->{RESPONSE} = $ua->simple_request( $request );
    print STDERR $self->{RESPONSE}->headers_as_string() if $self->verbose();
    if ( $self->{RESPONSE}->is_error )
    {
        die 
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
        die ref($self), ": $_ field is required\n" unless $self->{$_};
    }
    my $message_length = 
        length( $self->{subject} ) + length( $self->{message} )
    ;
    if ( $message_length > $MAX_CHARS )
    {
        die ref($self), 
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
