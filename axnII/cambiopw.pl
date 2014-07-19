#!/usr/bin/perl -wT

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser); 
use DBI;
use strict;

print header;
print start_html("Password Change Results");

my $dbh = DBI->connect( "dbi:mysql:AXN", "mario", "oiram") or 	
    &dienice("Can't connect to db: $DBI::errstr");
	
my $oldpass = "oiram";
my $newpass1 = "nolose";
my $newpass2 = "nolose"; 

my $username="mario";
#if ($ENV{'REMOTE_USER'} =~ /^(\w{3,})$/) {
#   $username = $1;
#} else {
#   &dienice("Your username ($1) looks suspicious. Aborting...");
#}

my $sth = $dbh->prepare("select * from users where username = ?") or &dbdie;
$sth->execute($username) or &dbdie;
unless (my $rec = $sth->fetchrow_hashref) {
    &dienice("Can't find your username!?");
}

my $uinfo = $sth->fetchrow_hashref;

# now encrypt the old password and see if it matches what's in the database
if ($uinfo->{password} ne crypt($oldpass,substr($uinfo->{password},0,2)) ) {
   &dienice(qq(Your old password is incorrect. If you can't remember it, please use the <a href="../forgotpass.html">reset password</a> form instead.));
}

# a little redundant error checking to be sure they typed the same
# new password twice:
if ($newpass1 ne $newpass2) {
   &dienice("You didn't type the same thing for both new password fields. Please check it and try again.");
}

# ok, everything checks out. Now we encrypt the new one:
my $encpass = &encrypt($newpass1);

# now store it in the database...
$sth = $dbh->prepare("update users set password=? where username=?") or &dbdie; 
$sth->execute($encpass, $username) or &dbdie;

# Finally we print out a thank-you page telling the user what
# we've done.

print qq(<h2>Success!</h2>
<p>Your password has been changed!  Your new password is <b>$newpass1</b>.<p>
<a href="/book/ch20/secure2/">Click Here</a> to login again!</p>\n);
print end_html;

sub encrypt {
    my($plain) = @_;
    my(@salt) = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
    return crypt($plain, $salt[int(rand(@salt))] . $salt[int(rand(@salt))]);
}
	
sub dienice {
    my($msg) = @_;
    print "<h2>Error</h2>\n";
    print $msg;
    exit;
}

sub dbdie {
    my($package, $filename, $line) = caller;
    my($errmsg) = "Database error: $DBI::errstr<br>
                called from $package $filename line $line";
    &dienice($errmsg);
}


