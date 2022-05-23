use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use HTML::Template;
use CGI;
use CGI::Simple;
use DBI;
use utf8;

use lib './';
use utils;

# Connection config
my $dbname = 'd1pq7vqqhcnc0';
my $host = 'ec2-176-34-211-0.eu-west-1.compute.amazonaws.com';
my $port = 5432;
my $username = 'kgazhzbgqrmkwr';
my $password = 'cfc6a9d1be371749ffb34751f19f9180b4215003ae20661e1ffcb0c0159b00b0';

my $dbh = DBI -> connect("dbi:Pg:dbname=$dbname;host=$host;port=$port",
                            $username,
                            $password,
                            {AutoCommit => 1, RaiseError => 1}
                         ) or die $DBI::errstr;

$SIG{INT} = sub {
    $dbh -> disconnect;
};

my $d = HTTP::Daemon->new(
            ReuseAddr => 1,
            LocalAddr => 'localhost',
            LocalPort => 8000
        ) || die;

my $message = '';

print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    while (my $r = $c->get_request) {

        my $template_name = 'templates/login.tmpl';
        if ($r->method eq 'GET'){

            if ($r->uri->path eq "/") {
                $c->send_redirect( "/login" );
            }
            elsif ($r->uri->path eq "/login") {
                $template_name = 'templates/login.tmpl';
            }
            elsif ($r->uri->path eq "/signup") {
                $template_name = 'templates/signup.tmpl';
            }
            elsif ($r->uri->path eq "/logout") {
                $c->send_redirect( "/login" );
            }
            else {
                $c->send_error(RC_NOT_FOUND);
            }

            my $code = 200;
            my $response = HTTP::Response->new( $code );
            $response->header('Content-Type'=>'text/html');

            my $template = HTML::Template->new(
                filename => $template_name,
                utf8     => 1
            );
            $template->param(MESSAGE => $message);
            my $content = $template->output;
            utf8::encode($content);
            $response->content($content);
            $c->send_response($response);
            $message = '';

        }
        if ($r->method eq 'POST'){

            my @form_data = split(/&/, $r->content);
            my $template;
            if ($r->uri->path eq "/") {

                my $asia_cities = &get_cities_by_continent('Asia', $dbh);
                my $america_cities = &get_cities_by_continent('America', $dbh);
                my $africa_cities = &get_cities_by_continent('Africa', $dbh);
                my $europe_cities = &get_cities_by_continent('Europe', $dbh);

                my $login = (split(/=/, $form_data[0]))[1];
                my $password = (split(/=/, $form_data[1]))[1];

                # валидация данных
                if ($password != &get_password_by_login($login, $dbh)) {
                    $message = "Неправильный логин или пароль";
                    $c->send_redirect( "/login");
                }

                $template = HTML::Template->new(
                    filename => 'templates/index.tmpl',
                    utf8     => 1
                );
                $template->param(
                    LOGIN => $login,
                    ASIA_CITIES => $asia_cities,
                    AMERICA_CITIES => $america_cities,
                    AFRICA_CITIES => $africa_cities,
                    EUROPE_CITIES => $europe_cities
                );
            }
            if ($r->uri->path eq "/login") {
                # если данные не валидны, определяем сообщение, которое будет
                # выводиться и делаем редирект на сайнап

                my $login = (split(/=/, $form_data[0]))[1];
                my $email = (split(/=/, $form_data[1]))[1];
                my $password = (split(/=/, $form_data[2]))[1];

                # валидация данных
                if ( &is_login_valid($login, $dbh) == 1 ){
                    if ( &is_email_valid($email, $dbh) == 1 ) {
                        &create_user( $login, $email, $password, $dbh );
                    } else {
                        $message = 'Учетная запись с данной почтой уже существует';
                        $c->send_redirect( "/signup");
                    }
                } else {
                    $message = 'Учетная запись с таким логином уже существует';
                    $c->send_redirect( "/signup");
                }

                $template = HTML::Template->new(
                    filename => 'templates/login.tmpl',
                    utf8     => 1
                );
                $template->param(MESSAGE => $message);
            }
            my $code = 200;
            my $response = HTTP::Response->new( $code );
            $response->header('Content-Type'=>'text/html');
            my $content = $template->output;

            utf8::encode($content);

            $response->content($content);
            $c->send_response($response);
        }
    }

    $c->close;
    undef($c);
}
