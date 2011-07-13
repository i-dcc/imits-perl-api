package MyTest::iMits;

use strict;
use warnings FATAL => 'all';

use base qw( Test::Class Class::Data::Inheritable );
use FindBin;
use Test::Most;
use Data::Dumper;

BEGIN {
    __PACKAGE__->mk_classdata( class => 'iMits' );
}

sub start_up : Tests( startup => 1 ) {
    my $test = shift;

    use_ok $test->class;
}

sub constructor : Tests( setup => 3 ) {
    my $test = shift;

    can_ok $test->class, 'new';
    ok my $o = $test->class->new(
            proxy_url => 'http://wwwcache.sanger.ac.uk:3128/',
            base_url  => 'http://htgt.internal.sanger.ac.uk:4008/labs/imits/',
            username  => 'htgt@sanger.ac.uk',
            password  => 'password',
            realm     => 'Application'
        ),
        '... the constructor succeeds';
    isa_ok $o, $test->class, '... the object it returns';

    $test->{obj} = $o;
}

sub base_url : Tests(3) {
    my $test = shift;

    can_ok $test->{obj}, 'base_url';
    isa_ok $test->{obj}->base_url, 'URI', '... the object it returns';
    is $test->{obj}->base_url, 'http://htgt.internal.sanger.ac.uk:4008/labs/imits/', '... default value set correctly';
}

sub proxy_url : Tests(3) {
    my $test = shift;

    can_ok $test->{obj}, 'proxy_url';
    return unless $test->{obj}->proxy_url;
    isa_ok $test->{obj}->proxy_url, 'URI', '... the object it returns';
    is $test->{obj}->proxy_url, 'http://wwwcache.sanger.ac.uk:3128/', '... default value set correctly';
}

sub ua : Tests(4) {
    my $test = shift;

    can_ok $test->{obj}, 'ua';
    isa_ok $test->{obj}->ua, 'LWP::UserAgent', '... the object it returns';
    is $test->{obj}->ua->proxy('http'), $test->{obj}->proxy_url, '... proxy set correctly';
    ok $test->{obj}->ua->get_basic_credentials( $test->{obj}->realm, $test->{obj}->base_url ),
        '... the user is authenticated';
}

sub uri_for : Tests(3) {
    my $test = shift;

    my $o = $test->{obj};
    can_ok $o, 'uri_for';
    is $o->uri_for('foo'), $o->base_url . "foo", '... simple uri built correctly';
    is $o->uri_for( 'foo', { bar => 1 } ), $o->base_url . "foo?bar=1", '... uri with params built correctly';
}

sub request : Tests(2) {
    my $test = shift;

    can_ok $test->{obj}, 'request';
    isa_ok $test->{obj}->request( 'GET', 'mi_attempts.json', { production_centre_name_equals => 'APN' } ), 'ARRAY', '... the object it returns';
}

sub create : Tests( setup => 3 ) {
    my $test = shift;
    my $o    = $test->{obj};
    
    can_ok $o, 'create_mi_attempt';
    isa_ok my $mi = $o->create_mi_attempt(
            {
                es_cell_name => 'EPD0027_2_B01',
                mi_date      => '2011-06-13'
            }
        ),
        'HASH', '... the object it returns';
    is $mi->{production_centre_name}, 'WTSI', '... production centre set correctly';
    
    $test->{mi} = $mi;
}

sub find : Tests(2) {
    my $test = shift;
    my $o    = $test->{obj};

    can_ok $o, 'find_mi_attempt';
    isa_ok $o->find_mi_attempt({ es_cell_name_equals => 'EPD0027_2_B01', mi_date_equals => '2011-06-13' }), 'ARRAY', '... the object it returns';
}

sub update : Tests(3) {
    my $test = shift;
    my $o    = $test->{obj};

    can_ok $o, 'update_mi_attempt';
    if ( defined $test->{mi}{id} ) {
        isa_ok $o->update_mi_attempt( $test->{mi}{id}, { blast_strain_name => 'C57BL/6J-Tyr<c-Brd>' } ), 'HASH', '... the object it returns';

        my $mi = $o->find_mi_attempt({ id_equals => $test->{mi}{id} })->[0];
        is $mi->{blast_strain_name}, 'C57BL/6J-Tyr<c-Brd>', '... blast_strain_name updated correctly';
    }
    else {
        $test->builder->skip( "no mi_attempt id to update" );
    }
}

sub delete : Tests( teardown => 2 ) {
    my $test = shift;
    my $o    = $test->{obj};

    can_ok $o, 'delete_mi_attempt';
    $test->builder->skip( "delete_mi_attempt is not enabled yet" );

    # if ( defined $test->{mi}{id} ) {
    #     ok $o->delete_mi_attempt( $test->{mi}{id} ), '... the object is deleted';
    # }
    # else {
    #     $test->builder->skip( "no mi_attempt id to delete" );        
    # }
}

1;

__END__
