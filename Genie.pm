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
gateway (L<http://www.genie.co.uk/>).

=head1 SYNOPSIS

    my $sms = Net::SMS->new(
        autotruncate => 1,
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
Genie (L<http://www.genie.co.uk/>) and uses form submission to a URL that may be
subject to change. The Genie service is currently only available to UK mobile
phone users.

There is a maximum length for SMS subject + message (123 for Genie). If the sum
of subject and message lengths exceed this, the behaviour of the
Net::SMS::Genie objects depends on the value of the 'autotruncate' argument to
the constructor. If this is a true value, then the subject / message will be
truncated to 123 characters. If false, the object will throw an exception
(croak).

=cut

#------------------------------------------------------------------------------
#
# Package globals
#
#------------------------------------------------------------------------------

use vars qw($VERSION $BASE_URL $SEND_URL %REQUIRED_KEYS %LEGAL_KEYS $MAX_CHARS);
$VERSION = '0.008';
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
    autotruncate => 1,
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

=head1 CONSTRUCTOR

The constructor for Net::SMS::Genie takes the following arguments as hash
values (see L<SYNOPSIS>):

=head2 autotruncate (OPTIONAL)

Genie as a upper limit on the length of the subject + message (123). If
autotruncate is true, subject and message are truncated to 123 if the sum of
their lengths exceeds 123. The heuristic for this is simply to treat subject
and message as a string and truncate it (i.e. if length(subject) >= 123 then
message is truncated to 0. Thanks to Mark Zealey <mark@itsolve.co.uk> for this
suggestion. The default for this is false.

=head2 username (REQUIRED)

The Genie username for the user (assuming that the user is already registered
at L<http://www.genie.co.uk/>.

=head2 password (REQUIRED)

The Genie password for the user (assuming that the user is already registered
at L<http://www.genie.co.uk/>.

=head2 recipient (REQUIRED)

Mobile number for the intended SMS recipient.

=head2 subject (REQUIRED)

SMS message subject.

=head2 message (REQUIRED)

SMS message body.

=head2 verbose (OPTIONAL)

If true, various soothing messages are sent to STDERR. Defaults to false.

=cut

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
    $ua->env_proxy();
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
    my $message_length;
    if ( $self->{autotruncate} )
    {
        $message_length = 0;
        # Chop the message down the the correct length. Also supports subjects
        # > $MAX_CHARS, but I think it's a bit stupid to send one, anyway ...
        # - Mark Zealey
        $self->{subject} = substr $self->{subject}, 0, $MAX_CHARS;
        $self->{message} = 
            substr $self->{message}, 0, $MAX_CHARS - length $self->{subject}
        ;
        $message_length += length $self->{$_} for qw/subject message/;
    }
    else
    {
        $message_length = 
            length( $self->{subject} ) + length( $self->{message} )
        ;
        if ( $message_length > $MAX_CHARS )
        {
            confess ref($self), 
                ": total message length (subject + message)  is too long ",
                "(> $MAX_CHARS)\n"
            ;
        }
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

#------------------------------------------------------------------------------
#
# More POD ...
#
#------------------------------------------------------------------------------

=head1 ENVIRONMENT VARIABLES

Net::SMS::Genie uses LWP::UserAgent to make requests to the Genie gateway. If
you are web browsing behind a proxy, you need to set an $http_proxy environment
variable; see the documentation for the env_proxy method of LWP::UserAgent for
more information.

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;
