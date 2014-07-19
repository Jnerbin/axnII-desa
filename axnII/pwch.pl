#!/usr/bin/perl
    use DBI;
    use CGI::Carp qw(fatalsToBrowser); 
    print "Content-type:text/html\n\n";
    
    $dbh = DBI->connect( "dbi:mysql:AXN", "mario", "oiram") or    
        &dienice("Can't connect to db: ",$dbh->errstr);
        
    read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    @pairs = split(/&/, $buffer);
    @keys = ();
    foreach $pair (@pairs) {
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        push(@keys, $name);
        $FORM{$name} = $value;
    }
        
    $oldpass = $FORM{'oldpass'};
    $newpass1 = $FORM{'newpass1'};
    $newpass2 = $FORM{'newpass2'};
    
    $username = "mario";
    
    $sth = $dbh->prepare("select * from users where username = ?") or &dienice("Can't select from table: ",$dbh->errmsg); 
    $sth->execute($username);
    $hashref = $sth->fetchrow_hashref;
    %uinfo = %{$hashref};
    if (!(scalar %uinfo)) {        # this really shouldn't ever happen...
        &dienice("Can't find your username!?");
    }

    # now encrypt the old password and see if it matches what's in the database
    if ($uinfo{password} ne crypt($oldpass,substr($uinfo{password},0,2)) ) {
       &dienice("Your old password is incorrect.");
    }
    
    # a little redundant error checking to be sure they typed the same
    # new password twice:
    if ($newpass1 ne $newpass2) {
       &dienice("You didn't type the same thing for both new password fields. Please check it and try again.");
    }
    
    # ok, everything checks out. Now we encrypt the new one:
    $encpass = &encrypt($newpass1);
    
    # now store it in the database...
    $sth = $dbh->prepare("update users set password=? where username=?") or &dienice("Can't add data to user table: ",$dbh->errmsg); 
    $sth->execute($encpass, $username);

    # we're not sending mail this time.

    # Finally we print out a thank-you page telling the user what
    # we've done.
    
print <<EndHTML;
    <html><head><title>Password Changed</title></head>
    <body>
    <h2>Success!</h2>
    Your password has been changed!  Your new password is <b>$newpass1</b>.<p>
    <a href="/class/password/secure2/">Click Here</a> to login again!<p>
    </body>
    </html>
EndHTML
        
    sub encrypt {
        my($plain) = @_;
        my(@salt);
        @salt = ('a'..'z', 'A'..'Z', '0'..'9', '.', '/');
        srand(time() ^ ($$ + ($$ << 15)) );
        return crypt($plain, $salt[int(rand(@salt))] . $salt[int(rand(@salt))]  );
    }

    sub dienice {
        my($msg) = @_;
        print "<h2>Error</h2>\n";
        print $msg;
        exit;
    }
