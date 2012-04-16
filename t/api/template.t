
use strict;
use warnings;

use RT::Test tests => 8;

use_ok('RT::Template');

my $queue = RT::Test->load_or_create_queue( Name => 'Templates' );
ok $queue && $queue->id, 'loaded or created queue';

{
    my $template = RT::Template->new(RT->SystemUser);
    isa_ok($template, 'RT::Template');
}

{
    my $template = RT::Template->new(RT->SystemUser);
    my ($val,$msg) = $template->Create(
        Queue => $queue->id,
        Name => 'Test',
        Content => 'This is template content'
    );
    ok($val,$msg);

    is( $template->Name, 'Test');
    is( $template->Content, 'This is template content', "We created the object right");

    ($val, $msg) = $template->SetContent( 'This is new template content');
    ok($val,$msg);
    is($template->Content, 'This is new template content', "We managed to _Set_ the content");
}

note "can not create template with duplicate name";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok(!$val,$msg);
}

{
    my $t = RT::Template->new(RT->SystemUser);
    $t->Create(Name => "Foo", Queue => 1);
    my $t2 = RT::Template->new(RT->Nobody);
    $t2->Load($t->Id);
    ok($t2->QueueObj->id, "Got the template's queue objet");
}

sub clean_templates {
    my %args = (@_);

    my $templates = RT::Templates->new( RT->SystemUser );
    $templates->Limit( FIELD => 'Queue', VALUE => $args{'Queue'} )
        if defined $args{'Queue'};
    $templates->Limit( FIELD => 'Name', VALUE => $_ )
        foreach ref $args{'Name'}? @{$args{'Name'}} : ($args{'Name'}||());
    while ( my $t = $templates->Next ) {
        $t->Delete;
    }
}

