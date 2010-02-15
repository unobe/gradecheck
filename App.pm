#!/home/unobe/perl/5.8.9/bin/perl

package App;
use base 'Squatting';
#use App::Controllers;
#use App::Views;
our %CONFIG = (
    PWD => '/home/unobe/sites/rurs.us/private/www/gradecheck',
    DATAFILE => 'data.json',
);

package App::Controllers;
use Squatting ':controllers';
our @C = (
    C(
        Home => [ '/'],
        get  => sub {
            my ($self) = @_;
            my $v = $self->v;
            $self->redirect(R('Login'));
        },
        post => sub { },
    ),
    C(
        Login => [ '/login'],
        get  => sub {
            my ($self, $param) = @_;
            my $v = $self->v;
            $v->{title} = 'Grade Check - Login';
            $v->{error} = $self->input->{error};
            $self->render('login');
        },
        post => sub {
        },
    ),
    C(
        Grades => [ '/grades'],
        get  => sub { 
            my ($self) = @_;
            $self->redirect(R('Login'));
        },
        post => sub {
            my ($self) = @_;
            my $v = $self->v;
            App::Models::load_data();
            $v->{period} = $self->input->{period};
            $v->{last5} = $self->input->{student_id};
            my $key = join '-', $v->{period}, $v->{last5};
            if (exists $App::Models::record{$key}) {
                $v->{title} = 'Grades';
                $v->{data} = $App::Models::record{$key};
                $v->{student} = shift @{$v->{data}};
                $self->render('gradesheet');
            }
            else {
                $self->redirect(R('Login', { error => 'Invalid period or student ID'  } ));
            }
        }
    )
);

package App::Views;
use Squatting ':views';
our @V = (
    V(
        'html',
        layout  => sub {
            my ($self, $v, $content) = @_;
            qq{<html><head><title>$v->{title}</title></head>
                <style type="text/css">}. $self->{_css}->().'</style>'
            .qq{<body>$content<br><br><br><br><div id="footer">Copyright (c) 2010 David Romano. All Rights Reserved.</div></body></html>};
        },
        home => sub {
            my ($self, $v) = @_;
            qq{<h1>$v->{message}</h1>\n<a href="login">Log in</a>}
        },
        login => sub {
            my ($self, $v) = @_;
            qq{<div id="error">$v->{error}</div>}
            .q{<div id="form_instructions">Please login</div>}
            .qq{<form action="grades" method="post" id="login" name="login">
                <label for="period">Period: </label>
                <input type="text" id="period" name="period" size="1" maxlength="1"><br>
                <label for="student_id">Last 5 Digits of Student ID: </label>
                <input type="password" id="student_id" name="student_id" size="5" maxlength="5"><br>
                <input type="submit" value="Log in">
                </form>}
        },
        gradesheet => sub {
            my ($self, $v) = @_;
            my $gen_time = scalar localtime((stat($App::CONFIG{PWD}.'/'.$App::CONFIG{DATAFILE}))[9]);
            my $content = qq{<h1 align="center">Gradesheet (generated at $gen_time )</h1>};
            $content .= qq{<h1 align="center">};
            $content .= qq{| ID: XX$v->{last5} | Period $v->{student}->[0] };
            $content .= qq{| Grade Level: $v->{student}->[3] | Percentage: } . sprintf("%.2f", $v->{student}->[4]) . qq{% | </h1><br><br>};
            $content .= q{<table><tr>} . (join '', map { "<th>$_</th>" } qw/# Date Title Earned Possible/, 'Total Unexcused', 'Total Excused', 'Total Earned', 'Total Possible') . q{</tr>};
            my $alternate = 0;
            for my $assignment (@{$v->{data}}) {
                for my $item (@$assignment) {
                    my $class = '';
                    if ($alternate % 2) {
                        $class = 'class="alternate"';
                    }
                    $content .= "<tr $class>";
                    $content .= qq{<td $class>$_</td>} for @$item;
                    $content .= '</tr>';
                    $alternate++;
                }
            }
            $content .= '</table>';
            return $content;
        },
        _css => sub {
            my ($self) = @_;
            # Load css from non-accessible directory
            open my $fh, '<', "$CONFIG{PWD}/main.css";
            my $css = join "\n", <$fh>;
            close $fh;
            return $css;
        }
    ),
);

package App::Models;
use JSON;

our %record;
our $data;
our $refresh_time = time + 45*60;

sub load_data {
    #return if keys %record && $refresh_time < time;
    #$refresh_time = time + 45*60; # every 45 minutes...
    open my $fh, '<', $App::CONFIG{PWD}.'/'.$App::CONFIG{DATAFILE};
    $data = join "\n", <$fh>;
    close $fh;

    %record = %{decode_json $data};
    return;
}

1;
