
use strict;
use Getopt::Long::Descriptive;
use Data::Dumper;
use Bio::P3::Workspace::WorkspaceClient;
use Bio::P3::Workspace::ScriptHelpers;
use Text::Table;
=head1 NAME

ws-create

=head1 SYNOPSIS

ws-create ws-name

=head1 DESCRIPTION

Create a workspace

=head1 COMMAND-LINE OPTIONS

ws-create workspace [long options...]
	--url      URL to use for workspace service
	--help     print usage message and exit
	
=cut

my @options = (["url=s", 'Service URL'],
		   ["permission|p", "Permissions for folders created"],
	       ["help|h", "Show this usage message"],
	       );

my($opt, $usage) = describe_options("%c %o ws-name",
				    @options);

my $name = shift;
my $type = shift;
my $filename = shift;
open (my $fh, "<", $filename);
my $data = "";
while (my $line = <$fh>) {
    $data .= $line;
}
close($fh);

print($usage->text), exit if $opt->help;

my $ws = Bio::P3::Workspace::ScriptHelpers::wsClient($opt->url);

my $list = $ws->create({
	objects => [[$name,$type,{},$data]],
	permission => $opt->permission,
	overwrite => 1
});
my $tbl = [];
for my $file (@$list) {
	my($name, $type, $path, $created, $id, $owner, $size, $user_meta, $auto_meta, $user_perm,
	$global_perm, $shockurl) = @$file;
	push(@$tbl, [$name, $owner, $type, $created, $size, $user_perm, $global_perm]);
}
my $table = Text::Table->new(
	"Name","Owner","Type","Moddate","Size","User perm","Global perm"
);
$table->load(@{$tbl});
print $table."\n";
