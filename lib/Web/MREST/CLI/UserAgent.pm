# ************************************************************************* 
# Copyright (c) 2014-2015-2015, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 
#
# This module maintains an LWP::UserAgent object which is used to communicate
# with the server via calls to the send_req function (exported by this module).
# The user agent is initialized by bin/mrest-cli and send_req is called by
# Web::MREST::CLI::Parser.
# 

package Web::MREST::CLI::UserAgent;

use 5.012;
use strict;
use warnings;

use App::CELL qw( $CELL $log $site $meta );
use Data::Dumper;
use Encode;
use Exporter qw( import );
use File::HomeDir;
use File::Spec;
use HTTP::Request::Common qw( GET PUT POST DELETE );
use JSON;
use LWP::UserAgent;
use LWP::Protocol::https;
#print "LWP::UserAgent: ".LWP::UserAgent->VERSION,"\n";
#print "LWP::Protocol::https: ".LWP::Protocol::https->VERSION,"\n";
use Params::Validate qw( :all );
use URI::Escape;

my %sh;
our $JSON = JSON->new->allow_nonref->convert_blessed->utf8->pretty;



=head1 NAME

Web::MREST::CLI::UserAgent - HTTP user agent for command-line client




=head1 SYNOPSIS

    use Web::MREST::CLI::UserAgent qw( send_req );

    my $status = send_req( 'GET', 'bugreport' );





=head1 EXPORTS

=cut

our @EXPORT_OK = qw( normalize_filespec send_req );





=head1 PACKAGE VARIABLES

=cut

# user agent
my $ua = LWP::UserAgent->new( 
    ssl_opts => { 
        verify_hostname => 1, 
    }
);

# dispatch table with references to HTTP::Request::Common functions
my %methods = ( 
    GET => \&GET,
    PUT => \&PUT,
    POST => \&POST,
    DELETE => \&DELETE,
);
             




=head1 FUNCTIONS


=head2 normalize_filespec

Given a filename (path) which might be relative or absolute, return an absolute
version. If the path was relative, it will be anchored to the home directory of
the user we are running as.

=cut

sub normalize_filespec {
    my $fs = shift;
    my $is_absolute = File::Spec->file_name_is_absolute( $fs );
    if ( $is_absolute ) {
        return $fs;
    }
    return File::Spec->catfile( File::HomeDir->my_home, $fs );
}


=head2 init_ua

Initialize the LWP::UserAgent singleton object.

=cut

sub init_ua {
    $ua->cookie_jar( { file => normalize_filespec( $site->MREST_CLI_COOKIE_JAR ) } );
    return;
}


=head2 cookie_jar

Return the cookie_jar associated with our user agent.

=cut

sub cookie_jar { $ua->cookie_jar };


=head2 send_req

Send a request to the server, get the response, convert it from JSON, and
return it to caller. Die on unexpected errors.

=cut

sub send_req {
    no strict 'refs';
    # process arguments
    my ( $method, $path, $body_data ) = validate_pos( @_,
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR|UNDEF, optional => 1 },
    );
    $log->debug( "Entering " . __PACKAGE__ . "::send_req with $method $path" );
    if ( ! defined( $body_data ) ) {
        # HTTP::Message 6.10 complains if request content is undefined
        $log->debug( "No request content given; setting to empty string" );
        $body_data = '';
    }

    # initialize suppressed headers hash %sh
    map { 
        $log->debug( "Suppressing header $_" );
        $sh{ lc $_ } = ''; 
    } @{ $site->MREST_CLI_SUPPRESSED_HEADERS } unless %sh;

    $path = "/$path" unless $path =~ m/^\//;
    $log->debug("send_req: path is $path");

    # convert body data to UTF-8
    my $encoded_body_data = encode( "UTF-8", $body_data );

    # assemble request
    my $url = $meta->MREST_CLI_URI_BASE || 'http://localhost:5000';
    $url .= uri_escape( $path, '%' );
    $log->debug( "Encoded URI is $url" );
    my $r = $methods{$method}->( 
        $url,
        Accept => 'application/json',
        Content_Type => 'application/json',
        Content => $body_data,
    );

    # add basic auth
    my $user = $meta->CURRENT_EMPLOYEE_NICK || 'demo';
    my $password = $meta->CURRENT_EMPLOYEE_PASSWORD || 'demo';
    $log->debug( "send_req: basic auth user $user / pass $password" );
    $r->authorization_basic( $user, $password );

    # send request, get response
    my $response = $ua->request( $r );
    $log->debug( "Response is " . Dumper( $response ) );
    my $code = $response->code;

    # process response entity
    my $status;
    my $content = $response->content;
    #$log->debug( "Response entity is " . Dumper( $content ) );
    if ( $content ) {
        my $unicode_content = decode( "UTF-8", $content );

        # if the content is a bare string, enclose it in double quotes
        if ( $unicode_content =~ m/^[^\{].*[^\}]$/s ) {
            $unicode_content =~ s/\n//g;
            $log->debug( "Adding double quotes to bare JSON string" );
            $unicode_content = '"' . $unicode_content . '"';
        }

        my $perl_scalar = $JSON->decode( $unicode_content );

        if ( ref( $perl_scalar ) ) {
            # if it's a hash, we have faith that it will bless into a status object
            $status = bless $perl_scalar, 'App::CELL::Status';
        } else { 
            $status = $CELL->status_err( 'MREST_OTHER_ERROR_REPORT_THIS_AS_A_BUG', payload => $perl_scalar );
            $log->error("Unexpected HTTP response ->$perl_scalar<-" );
        }
    } else {
        $status = $CELL->status_warn( 'MREST_CLI_HTTP_REQUEST_OK_NODATA' );
    }
    $status->{'http_status'} = $response->code . ' ' . $response->message;

    # load up headers
    $status->{'headers'} = {};
    $response->headers->scan( sub {
        my ( $h, $v ) = @_;
        $status->{'headers'}->{$h} = $v unless exists $sh{ lc $h };
    } );
    return $status;
}

