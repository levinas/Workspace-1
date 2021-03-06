use FindBin qw($Bin);
use Test::More;
use Config::Simple;
use JSON;
use Data::Dumper;
use Bio::P3::Workspace::WorkspaceImpl;
use Bio::KBase::AuthToken;
use File::Path;
use REST::Client;
use LWP::UserAgent;
use JSON::XS;
use HTTP::Request::Common;
my $test_count = 39;

BEGIN {
	use_ok( Bio::P3::Workspace::WorkspaceImpl );
}

#if (!defined $ENV{KB_DEPLOYMENT_CONFIG} || !-e $ENV{KB_DEPLOYMENT_CONFIG}) {
    $ENV{KB_DEPLOYMENT_CONFIG}=$Bin."/../../configs/test.cfg";
#}
print "Loading server with this config: ".$ENV{KB_DEPLOYMENT_CONFIG}."\n";

my $testuserone = "reviewer";
my $tokenObj = Bio::KBase::AuthToken->new(
    user_id => $testuserone, password => 'reviewer',ignore_authrc => 1
);
my $testusertwo = "chenry";
#Setting context to authenticated user one
$Bio::P3::Workspace::Service::CallContext = undef;
setcontext(2);
my $ws = Bio::P3::Workspace::WorkspaceImpl->new();

#Clearing out previous test results
my $output = $ws->ls({
	paths => [""],
	adminmode => 1
});
if (defined($output->{""})) {
	my $hash = {};
	for (my $i=0; $i < @{$output->{""}}; $i++) {
		my $item = $output->{""}->[$i];
		print $item->[2].$item->[0]."\n";
		$hash->{$item->[2].$item->[0]} = 1;
	}
	if (defined($hash->{"/chenry/TestWorkspace"})) {
		$output = $ws->delete({
			objects => ["/chenry/TestWorkspace"],
			force => 1,
			deleteDirectories => 1,
			adminmode => 1
		});
	}
	if (defined($hash->{"/reviewer/TestWorkspace"})) {
		$output = $ws->delete({
			objects => ["/reviewer/TestWorkspace"],
			force => 1,
			deleteDirectories => 1,
			adminmode => 1
		});
	}
	if (defined($hash->{"/reviewer/TestAdminWorkspace"})) {
		$output = $ws->delete({
			objects => ["/reviewer/TestAdminWorkspace"],
			force => 1,
			deleteDirectories => 1,
			adminmode => 1
		});
	}
}

#Setting context to authenticated user one
can_ok("Bio::P3::Workspace::WorkspaceImpl", qw(
    create
    get
    ls
    copy
    delete
    set_permissions
    list_permissions
    version
   )
);

#Creating a private workspace as "$testuserone"
setcontext(1);
my $output = $ws->create({
	objects => [["/reviewer/TestWorkspace","folder",{description => "My first workspace!"},undef]],
	permission => "n"
});
ok defined($output), "Successfully created a top level directory!";
print "create output:\n".Data::Dumper->Dump($output)."\n\n";

#Creating a public workspace as "$testusertwo"
setcontext(2);
$output = $ws->create({
	objects => [["/chenry/TestWorkspace","folder",{description => "My first workspace!"},undef]],
	permission => "r"
});
ok defined($output), "Successfully created a top level directory!";
print "create output:\n".Data::Dumper->Dump($output)."\n\n";
#Testing testusertwo acting as an adminitrator
setcontext(2);
$output = $ws->create({
	objects => [["/reviewer/TestAdminWorkspace","folder",{description => "My first admin workspace!"},undef,0]],
	permission => "r",
	adminmode => 1,
	setowner => "reviewer"
});
ok defined($output), "Successfully created a top level directory!";
print "create output:\n".Data::Dumper->Dump($output)."\n\n";
#Attempting to make a workspace for another user
setcontext(2);
$output = undef;
eval {
	print Data::Dumper->Dump([$Bio::P3::Workspace::Service::CallContext])."\n";
	$output = $ws->create({
		objects => [["/reviewer/OtherTestWorkspace","folder",{description => "My second workspace!"},undef]],
		permission => "r"
	});
};
ok !defined($output), "Creating a top level directory for another user should fail!";
#Getting workspace metadata
setcontext(2);
$output = $ws->get({
	metadata_only => 1,
	objects => ["/chenry/TestWorkspace"]
});
ok defined($output), "Successfully ran get function to retrieve workspace metadata!";
print "get output:\n".Data::Dumper->Dump($output)."\n\n";
#Listing workspaces as "$testusertwo"
setcontext(2);
$output = $ws->ls({
	paths => [""]
});
delete $ctxtwo->{_wscache};
delete $ctxone->{_wscache};
ok defined($output->{""}->[0]) && !defined($output->{""}->[2]), "Successfully ran ls function on got one workspace back!";
print "list_workspaces output:\n".Data::Dumper->Dump([$output])."\n\n";

#Listing workspaces as "$testuserone"
setcontext(1);
$output = $ws->ls({
	paths => [""]
});
ok defined($output->{""}->[2]), "Successfully ran ls function on got three workspaces back!";
print "ls output:\n".Data::Dumper->Dump([$output])."\n\n";

#Listing workspaces as "$testuserone" but restricting to owned only
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/"]
});
ok defined($output->{"/$testuserone/"}->[1]) && !defined($output->{"/$testuserone/"}->[2]), "Successfully ran ls function and got two workspace back!";
print "list_workspaces output:\n".Data::Dumper->Dump([$output])."\n\n";

#Saving an object
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/testobj","genome",{"Description" => "My first object!"},{
		id => "83333.1",
		scientific_name => "Escherichia coli",
		domain => "Bacteria",
		dna_size => 4000000,
		num_contigs => 1,
		gc_content => 0.5,
		taxonomy => "Bacteria",
		features => [{}]
	}]]
});
ok defined($output->[0]), "Successfully ran save_objects action!";
print "save_objects output:\n".Data::Dumper->Dump($output)."\n\n";
#Testing overwrite
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/testobj","genome",{"Description" => "My first object!"},{
		id => "83333.1",
		scientific_name => "Escherichia coli",
		domain => "Bacteria",
		dna_size => 4000000,
		num_contigs => 1,
		gc_content => 0.5,
		taxonomy => "Bacteria",
		features => [{}]
	}]],
	overwrite => 1
});
ok defined($output->[0]), "Successfully ran save_objects action!";
print "save_objects output:\n".Data::Dumper->Dump($output)."\n\n";
#Testing overwrite
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/testobj","genome",{"Description" => "My first object!"},{
		id => "83333.1",
		scientific_name => "Escherichia coli",
		domain => "Bacteria",
		dna_size => 4000000,
		num_contigs => 1,
		gc_content => 0.5,
		taxonomy => "Bacteria",
		features => [{}]
	}]],
	overwrite => 1
});
ok defined($output->[0]), "Successfully ran save_objects action!";
print "save_objects output:\n".Data::Dumper->Dump($output)."\n\n";
#Listing workspaces as "$testuserone" but restricting to owned only
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/"]
});
ok defined($output->{"/$testuserone/TestWorkspace/testdir/testdir2/testdir3/"}->[0]) && !defined($output->{"/$testuserone/TestWorkspace/testdir/testdir2/testdir3/"}->[1]), "Successfully ran ls function and got two workspace back!";
print "list_workspaces output:\n".Data::Dumper->Dump([$output])."\n\n";

#Recreating an existing folder
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir","folder",{"Description" => "My recreated folder!"},undef]]
});
ok !defined($output->[0]), "Successfully ran save_objects action!";

#Saving contigs
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/contigs","contigs",{"Description" => "My first contigs!"},">gi|284931009|gb|CP001873.1| Mycoplasma gallisepticum str. F, complete genome
TTTTTATTATTAACCATGAGAATTGTTGATAAATCTGTGGATAACTCTAAAAAAATTCCGGATTTATAAA
AGTACATTAAAATATTTATATTTTAATGTAAATATTATATCACTTTTTCACAAAAACGTGTATTATATAT
AAGGAGTTTTGTAAATTATTTAACTATATTACTATGTAATATAGTTATTATATCAAAACAAACTAAAACA
GTAGAGCAACCTTTAAAAATTAACTAAAAACTAAATACAAATTTGTTTATAGACGAAAGTTTTTCTATTA
ATATCCCCACATTAACTCTATCAAAACCCCTATACTAAAAAAAACACACTCTGAATACATAACTTGTATG
TAAAGTTTGAGTGAAGTTAAATCGCTTTAATATTGTAACAATATTGTTTGTAAAAATATTTATTTAATAT
GAAAAAAATATTGTGATTTTTATCGGAAATATTGTGATTTTCTAATTCAGGCCAATTAAAAATATCAAAA
CTAATTACTTAAATAAAAATATCAATAAATAAATTAAAAAACTTATTAACATTTCTACTAAGAGAGTTCG
TATTTGGAAATAATATTAAAGTAATACACAATATTAAAAAAATATTATTAGTATTTAAACGATTAAGTAC
TTTTTCATTCTTTTGTCTATCTGTAAAAGACACTAGGTAAGGATTACTTTATTAACAAGATAAAGAGAAA
AGAATTTATTTTTAATAATACGATTTTAATATTTTTAAAATATTATTCAATTTACGTTGTTTTATTACCA
AAAATAGAATATTAAAACAATATTTATAAGTTAATTAAAATTAATACTTTTTAAAACAAAACAACAATAT
TATTTCAATATGGTCACAGTAGTCACAATAAAGTTGATAATATTTAAATAATATTAATTAAATATTTATT
CAAGAATTTATTATTCTTGAATAACAGCAAAAAACTTTTATAGAACTGAAGAGCATTCTTAAAAAAGAAA
AAACCTAATGCTAACGGCATCAGAACTAACTAATACGAAAATAATATTTGATTACAAGAGAAGCAAATAA
TATTGTTAAGGGATCAATATTGTAATAATATTAAAATCATATCATAGAAGGTTAATGCTTACCAGTAATA
CTACTAACAGATAGTTTAATGTAGATGTATTAATATTGTAATAATATTAAAGTCATATTGTAAAAAGTTT
ATCTTTAGCAAAAAATACTACTAAACGGAGAATTTAATATAGATATATCATTAATATTTAAATAATATTA
CTTCATAAGGAAGCAATAATAACAAATATTCTTAACTTATAAATAAGCAATATATTAATAATATGGTAAC
AATATTGTTTTAATACTACATTCGTAATAAAGCTAGTTTAAGAGAATATTAAAATAATATTGGTTTGAAA
CTGTTAAAAATTATCTTTCTTAACAATATTGCCAAATCCGATTTTGCTTTACTTCAACGGGAATAAGTTT
TTAACTAAACTTTGCACTCTAATTACTAAAATATAAAAACAAACTTAGGACTAAAAAGATTTGAAATGAT
TAGCGTAAGGCTGAGGTTTTAGTTTAAATATACAAAGTAAAGTATTTTTTATTTAAAACAAGTTTTAAAA
ATACCAAAATGATATTTTATTAATATTGTTATCTATATCAAGATTTATAATATGTTTTCTTGAGCACTTT
TTTTCAAGATTGCCTAATAATAATATATTTTTAATATTTAATTACTAGGAAAATAATATTGCGAAAATTA"]]
});
ok defined($output->[0]), "Successfully ran save_objects action!";
print "save_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Creating shock nodes
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/shockobj","genome",{"Description" => "My first shock object!"}]],
	createUploadNodes => 1
});
ok defined($output->[0]), "Successfully ran create_upload_node action!";
print "create_upload_node output:\n".Data::Dumper->Dump($output)."\n\n";
#Uploading file to newly created shock node
print "Filename:".$Bin."/testdata.txt\n";
my $req = HTTP::Request::Common::POST($output->[0]->[11],Authorization => "OAuth ".$ctxone->{token},Content_Type => 'multipart/form-data',Content => [upload => [$Bin."/testdata.txt"]]);
$req->method('PUT');
my $ua = LWP::UserAgent->new();
my $res = $ua->request($req);
print "File uploaded:\n".Data::Dumper->Dump([$res])."\n\n";
$output = $ws->update_auto_meta({objects => ["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/shockobj"]});
print "update_auto_meta output:\n".Data::Dumper->Dump($output)."\n\n";

#Updating metadata
setcontext(2);
$output = $ws->update_metadata({
	objects => [["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/shockobj",undef,undef,0]],
	autometadata => 0,
	adminmode => 1
});
ok defined($output->[0]), "Successfully ran update_metadata action!";
print "update_metadata output:\n".Data::Dumper->Dump($output)."\n\n";

#Retrieving shock object through workspace API
setcontext(1);
$output = $ws->get({
	objects => ["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/shockobj"]
});
ok defined($output->[0]), "Successfully ran get function!";
print "get_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Listing objects
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace/testdir/testdir2"],
	excludeDirectories => 0,
	excludeObjects => 0,
	recursive => 1
});
ok defined($output->{"/$testuserone/TestWorkspace/testdir/testdir2"}), "Successfully listed all workspace contents!";
print "ls output:\n".Data::Dumper->Dump([$output])."\n\n";
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace"],
	excludeDirectories => 0,
	excludeObjects => 0,
	recursive => 0
});
ok defined($output->{"/$testuserone/TestWorkspace"}->[0]) && !defined($output->{"/$testuserone/TestWorkspace"}->[1]), "Successfuly listed workspace contents nonrecursively!";
print "list_workspace_contents output:\n".Data::Dumper->Dump([$output])."\n\n";
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace"],
	excludeDirectories => 1,
	excludeObjects => 0,
	recursive => 1
});
ok defined($output->{"/$testuserone/TestWorkspace"}->[0]) && !defined($output->{"/$testuserone/TestWorkspace"}->[3]), "Successfully listed workspace contents without directories!";
print "list_workspace_contents output:\n".Data::Dumper->Dump([$output])."\n\n";
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace"],
	excludeDirectories => 0,
	excludeObjects => 1,
	recursive => 1
});
ok defined($output->{"/$testuserone/TestWorkspace"}->[2]) && !defined($output->{"/$testuserone/TestWorkspace"}->[3]), "Successfully listed workspace contents without objects!";
print "list_workspace_contents output:\n".Data::Dumper->Dump([$output])."\n\n";

#Listing objects hierarchically
setcontext(1);
$output = $ws->ls({
	paths => ["/$testuserone/TestWorkspace"],
	excludeDirectories => 0,
	excludeObjects => 0,
	recursive => 1,
	fullHierachicalOutput => 1
});
ok defined($output->{"/$testuserone/TestWorkspace"}) && defined($output->{"/$testuserone/TestWorkspace/testdir"}), "Successfully listed workspace contents hierarchically!";
print "list_workspace_hierarchical_contents output:\n".Data::Dumper->Dump([$output])."\n\n";

#Copying workspace object
setcontext(1);
$output = undef;
eval {
$output = $ws->copy({
	objects => [["/$testuserone/TestWorkspace/testdir","/$testusertwo/TestWorkspace/copydir"]],
	recursive => 1
});
};
ok !defined($output), "Copying to a read only workspace fails!";

#Changing workspace permissions
setcontext(2);
$output = $ws->set_permissions({
	path => "/$testusertwo/TestWorkspace",
	permissions => [[$testuserone,"w"]]
});
ok defined($output), "Successfully ran set_workspace_permissions function!";
print "set_workspace_permissions output:\n".Data::Dumper->Dump($output)."\n\n";
#Listing workspace permission
setcontext(2);
$output = $ws->list_permissions({
	objects => ["/$testusertwo/TestWorkspace"]
});
ok defined($output->{"/$testusertwo/TestWorkspace"}->[0]), "Successfully ran list_workspace_permissions function!";
print "list_workspace_permissions output:\n".Data::Dumper->Dump([$output])."\n\n";

#Copying workspace object
setcontext(1);
$output = $ws->copy({
	objects => [["/$testuserone/TestWorkspace/testdir","/$testusertwo/TestWorkspace/copydir"]],
	recursive => 1
});
ok defined($output), "Successfully ran copy_objects function!";
print "copy_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Listing contents of workspace with copied objects
setcontext(1);
$output = $ws->ls({
	paths => ["/$testusertwo/TestWorkspace"],
	excludeDirectories => 0,
	excludeObjects => 0,
	recursive => 1
});
ok defined($output->{"/$testusertwo/TestWorkspace"}->[0]), "Successfully listed workspace contents!";
print "list_workspace_contents output:\n".Data::Dumper->Dump([$output])."\n\n";

#Changing global workspace permissions
setcontext(1);
$output = $ws->set_permissions({
	path => "/$testuserone/TestWorkspace",
	new_global_permission => "w"
});
ok defined($output), "Successfully changed global permissions!";
print "reset_global_permission output:\n".Data::Dumper->Dump($output)."\n\n";


#Moving objects
setcontext(2);
$output = $ws->copy({
	objects => [["/$testusertwo/TestWorkspace/copydir","/$testuserone/TestWorkspace/movedir"]],
	recursive => 1,
	move => 1
});
ok defined($output), "Successfully ran copy to move objects!";
print "move_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Deleting an object
setcontext(1);
$output = $ws->delete({
	objects => ["/$testuserone/TestWorkspace/movedir/testdir2/testdir3/testobj","/$testuserone/TestWorkspace/movedir/testdir2/testdir3/shockobj"]
});
ok defined($output), "Successfully ran delete_objects function on object!";
print "delete_objects output:\n".Data::Dumper->Dump($output)."\n\n";

setcontext(1);
$output = $ws->delete({
	objects => ["/$testuserone/TestWorkspace/movedir/testdir2/testdir3"],
	force => 1,
	deleteDirectories => 1
});
ok defined($output), "Successfully ran delete_objects function on directory!";
print "delete_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Deleting a directory
setcontext(1);
$output = $ws->delete({
	objects => ["/$testuserone/TestWorkspace/movedir"],
	force => 1,
	deleteDirectories => 1
});
ok defined($output), "Successfully ran delete_workspace_directory function!";
print "delete_workspace_directory output:\n".Data::Dumper->Dump($output)."\n\n";
#Creating a directory
setcontext(1);
$output = $ws->create({
	objects => [["/$testuserone/TestWorkspace/emptydir","folder",{},undef]]
});
ok defined($output), "Successfully ran create_workspace_directory function!";
print "create_workspace_directory output:\n".Data::Dumper->Dump($output)."\n\n";
#Getting an object
setcontext(1);
$output = $ws->get({
	objects => ["/$testuserone/TestWorkspace/testdir/testdir2/testdir3/testobj"]
});
ok defined($output->[0]->[1]), "Successfully ran get_objects function!";
print "get_objects output:\n".Data::Dumper->Dump($output)."\n\n";

#Getting an object by reference
setcontext(1);
$output = $ws->get({
	objects => [$output->[0]->[0]->[4]]
});
ok defined($output->[0]->[1]), "Successfully ran get_objects_by_reference function!";
print "get_objects_by_reference output:\n".Data::Dumper->Dump($output)."\n\n";

#Deleting workspaces
setcontext(1);
$output = $ws->delete({
	objects => ["/$testuserone/TestWorkspace"],
	force => 1,
	deleteDirectories => 1
});
ok defined($output), "Successfully ran delete_workspace function!";
print "delete_workspace output:\n".Data::Dumper->Dump($output)."\n\n";
#Setting context to authenticated user one
setcontext(2);
$output = $ws->delete({
	objects => ["/$testusertwo/TestWorkspace"],
	force => 1,
	deleteDirectories => 1
});
ok defined($output), "Successfully ran delete_workspace function!";
print "delete_workspace output:\n".Data::Dumper->Dump($output)."\n\n";

done_testing($test_count);

sub setcontext {
	my($context) = @_;
	if ($context == 1) {
		$Bio::P3::Workspace::Service::CallContext = Bio::P3::Workspace::ServiceContext->new($tokenObj->token(),"test",$testuserone);
	} else {
		$Bio::P3::Workspace::Service::CallContext = Bio::P3::Workspace::ServiceContext->new("un=chenry|tokenid=03B0C858-7A70-11E4-9DE6-FDA042A49C03|expiry=1449094224|client_id=chenry|token_type=Bearer|SigningSubject=http://rast.nmpdr.org/goauth/keys/E087E220-F8B1-11E3-9175-BD9D42A49C03|sig=085255b952c8db3ddd7e051ac4a729f719f22e531ddbc0a3edd86a895da851faa93249a7347c75324dc025b977e9ac7c4e02fb4c966ec6003ecf90d3148e35160265dbcdd235658deeed0ec4e0c030efee923fda1a55e8cc6f116bcd632fa6a576d7bf4a794554d2d914b54856e1e7ac2b071f81a8841d142123095f6af957cc","test",$testusertwo);
	}
}

package Bio::P3::Workspace::ServiceContext;

use strict;

sub new {
    my($class,$token,$method,$user) = @_;
    my $self = {
        token => $token,
        method => $method,
        user_id => $user
    };
    return bless $self, $class;
}
sub user_id {
	my($self) = @_;
	return $self->{user_id};
}
sub token {
	my($self) = @_;
	return $self->{token};
}
sub method {
	my($self) = @_;
	return $self->{method};
}