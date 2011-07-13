package iMits;

use strict;
use warnings FATAL => 'all';

use Moose;
use Moose::Util::TypeConstraints;
use LWP::UserAgent;
use namespace::autoclean;
use JSON;
use Readonly;
require URI;

with qw( MooseX::SimpleConfig MooseX::Log::Log4perl );

subtype 'iMits::URI' => as class_type('URI');

coerce 'iMits::URI' => from 'Str' => via { URI->new($_) };

has 'base_url'  => ( is => 'ro', isa => 'iMits::URI', coerce => 1, required => 1 );
has 'proxy_url' => ( is => 'ro', isa => 'iMits::URI', coerce => 1 );
has 'username'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'password'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'realm'     => ( is => 'ro', isa => 'Str', default => 'iMits' );
has 'ua'        => ( is => 'ro', isa => 'LWP::UserAgent', lazy_build => 1 );

sub _build_ua {
    my $self = shift;

    # Set proxy
    my $ua = LWP::UserAgent->new();
    $ua->proxy( http => $self->proxy_url ) if defined $self->proxy_url;

    # Set credentials
    if ( $self->username ) {
        $ua->credentials( $self->base_url->host_port, $self->realm, $self->username, $self->password );
    }

    return $ua;
}

#
#   Private methods
#

sub uri_for {
    my ( $self, $path, $params ) = @_;

    my $uri = URI->new_abs( $path, $self->base_url );
    if ($params) {
        $uri->query_form($params);
    }

    return $uri;
}

sub request {
    my ( $self, $method, $rel_url, $data ) = @_;

    my ( $uri, $request );

    if ( $method eq 'GET' or $method eq 'DELETE' ) {
        $uri = $self->uri_for( $rel_url, $data );
        $request = HTTP::Request->new( $method, $uri, [ content_type => 'application/json' ] );
    }
    elsif ( $method eq 'PUT' or $method eq 'POST' ) {
        $uri = $self->uri_for($rel_url);
        $request = HTTP::Request->new( $method, $uri, [ content_type => 'application/json' ], to_json($data) );
    }
    else {
        confess "Method $method unknown when requesting URL $uri";
    }

    $self->log->debug("$method request for $uri");
    if ( $data ) {
        $self->log->debug( sub { "Request data: " . to_json( $data ) } );        
    }
    my $response = $self->ua->request($request);
    if ( $response->is_success ) {
        # DELETE method does not return JSON.
        return $method eq 'DELETE' ? 1 : from_json( $response->content );
    }

    my $err_msg = "$method $uri: " . $response->status_line;
    
    if ( my $content = $response->content ) {
        $err_msg .= "\n $content";
    }
    
    confess $err_msg;
}

{
    my $meta = __PACKAGE__->meta;

    foreach my $key ( qw( mi_attempt ) ) {
        $meta->add_method(
            "find_$key" => sub {
                my ( $self, $params ) = @_;
                return $self->request( 'GET', sprintf( '%ss.json', $key ), $params );
            }
        );

        $meta->add_method(
            "update_$key" => sub {
                my ( $self, $id, $params ) = @_;
                return $self->request( 'PUT', sprintf( '%ss/%d.json', $key, $id ), { $key => $params } );
            }
        );

        $meta->add_method(
            "create_$key" => sub {
                my ( $self, $params ) = @_;
                return $self->request( 'POST', sprintf( '%ss.json', $key ), { $key => $params } );
            }
        );

        $meta->add_method(
            "delete_$key" => sub {
                my ( $self, $id ) = @_;
                return $self->request( 'DELETE', sprintf( '%ss/%d.json', $key, $id ) );
            }
        );
    }

    $meta->make_immutable;
}

1;

__END__
