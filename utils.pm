use strict;
use warnings;

our @ISA= qw( Exporter );

our @EXPORT = qw( get_password_by_login );


sub get_password_by_login(&&){
    my ($login, $dbh) = @_;

    my $sth = $dbh->prepare("SELECT password FROM users WHERE login = ?");
    $sth->execute( $login );

    my $password = $sth->fetchrow_array;
    return $password;
}


sub create_user(&&&) {
    my ($login, $email, $password, $dbh) = @_;

    # в почте меняем %40 на @
    my $find = "%40";
    my $replace = "@";
    $find = quotemeta $find;

    $email =~ s/$find/$replace/g;

    my $added_user = $dbh->do(
        "INSERT INTO users (id, login, email, password, authorization_cookie)".
        "VALUES (DEFAULT, '$login', '$email', '$password', NULL);") or die $dbh->errstr;
}


sub is_login_valid(&&) {
    my ($login, $dbh) = @_;

    my $sth = $dbh->prepare("SELECT login FROM users WHERE login = ?");
    $sth->execute( $login );

    my $login_from_db = $sth->fetchrow_array;
    if ( $login_from_db eq '' ) {
        return 1;
    } else {
        return 0;
    }
}


sub is_email_valid(&&) {
    my ($email, $dbh) = @_;

    # в почте меняем %40 на @
    my $find = "%40";
    my $replace = "@";
    $find = quotemeta $find;

    $email =~ s/$find/$replace/g;

    my $sth = $dbh->prepare("SELECT email FROM users WHERE email = ?");
    $sth->execute( $email );

    my $email_from_db = $sth->fetchrow_array;
    if ( $email_from_db eq '' ) {
        return 1;
    } else {
        return 0;
    }
}


sub get_cities_by_continent(&&){
    # returns array of cities
    my ($continent, $dbh) = @_;
    my $statement = "SELECT row_number() over (), c.city, c.country, population\n".
                    "FROM countries\n".
                    "INNER JOIN cities c on countries.country = c.country\n".
                    "INNER JOIN population p on c.city = p.city\n".
                    "WHERE continent = ?\n".
                    "ORDER BY population DESC";

    my $sth = $dbh->prepare($statement);
    $sth->execute($continent);

    my $cities = [];

    while ( my $city = $sth->fetchrow_hashref ) {
        my %city = %{$city};
        push @$cities, $city;
    }
    return $cities;
}
