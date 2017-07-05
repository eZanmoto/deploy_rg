// Copyright 2017 Sean Kelleher. All rights reserved.

var cp = require('child_process');
var fs = require('fs');
var https = require('https');
var qs = require('querystring');
var url = require('url');

// FIXME Some of the `seq` actions may leave the system in an inconsistent state
// if they are interrupted or fail.

var paths = {
    '/': function (req, resp) {
        resp.writeHead(200, {'Content-Type': 'text/html'});
        resp.write(
            '<a href="projects">Projects</a>'+
            '<ul>'+
                '<li><a href="gitd">Git Logs</a></li>'+
                '<li><a href="wall">Wall Logs</a></li>'+
                '<li><a href="lab">Lab Logs</a></li>'+
                '<li><a href="node">Node Logs</a></li>'+
            '</ul>'
        );
        resp.end();
    },
    '/gitd': readLogs('/var/tmp/gitd', ''),
    '/wall': readLogs('/var/tmp/frg', 'wall'),
    '/lab': readLogs('/var/tmp/frg', 'lab'),
    '/node': readLogs('/var/tmp/node', ''),
    '/projects': readProject(
        '<a href="projects/add">Add</a>',
        function (req, resp, projName) {
            fs.readFile('/var/tmp/repo_update/'+projName, 'utf8', function (err, data) {
                if (err) {
                    serverError(resp, err);
                    return;
                }

                resp.writeHead(200, {'Content-Type': 'text/html'});
                resp.write(
                    '<p><a href="projects/logs?name='+projName+'">Logs</a></p>'+
                    '<p><a href="projects/delete?name='+projName+'">Delete</a></p>'
                );
                resp.end();
            });
        }
    ),
    '/projects/add': function (req, resp) {
        // https://stackoverflow.com/a/19183959/497142
        if (req.method === "POST") {
            var body = '';
            req.on('data', function (data) {
                body += data;
                if (body.length > 1e7) {
                    resp.writeHead(413, {'Content-Type': 'text/html'});
                    resp.write('413 Payload Too Large');
                    resp.end();
                    return;
                }
            });
            req.on('end', function () {
                var form = qs.parse(body);
                var fields = ['username', 'password', 'host', 'user', 'project'];
                for (var i = 0; i < fields.length; i++) {
                    var field = fields[i];
                    if (!form[field]) {
                        console.log("missing '"+field+"'");
                        resp.writeHead(400, {'Content-Type': 'text/html'});
                        resp.write('400 Bad Request');
                        resp.end();
                        return;
                    }
                }

                // TODO Log command output.
                seq(
                    null,
                    [
                        seqExec(
                            'bash /home/repogate/deploy_rg/es-add.sh'+
                            ' '+process.env.ES_PASSWORD+
                            ' '+'/home/repogate/repos_pass.aes'+
                            ' '+form.project+
                            ' '+form.username+':'+form.password
                        ),
                        seqExecInDir(
                            'bash /home/repogate/deploy_rg/clone.sh'+
                            ' '+form.host+
                            ' '+form.user+
                            ' '+form.project+
                            ' '+'ES_PASSWORD'+
                            ' '+'/var/tmp/repo_update/'+form.project+
                            ' '+'/home/repogate/repos_pass.aes',
                            '/home/repogate/repos'
                        ),
                        function () {
                            resp.writeHead(200, {'Content-Type': 'text/html'});
                            resp.write('<script>document.location="/projects?name='+form.project+'";</script>');
                            resp.end();
                        },
                    ],
                    function (err) {
                        serverError(resp, err);
                    }
                );
            });
            return;
        }
        resp.writeHead(200, {'Content-Type': 'text/html'});
        resp.write(
            '<form method="POST">'+
                '://<input type="text" name="username" placeholder="username" size="10"/>'+
                ':<input type="password" name="password" placeholder="password" size="10"/>'+
                '@<input type="text" name="host" placeholder="host" size="10"/>'+
                '/<input type="text" name="user" placeholder="user" size="10"/>'+
                '/<input type="text" name="project" placeholder="project" size="10"/>.git'+
                '<input type="submit" />'+
            '</form>'
        );
        resp.end();
    },
    '/projects/delete': readProject(
        '',
        function (req, resp, projName) {
            seq(
                null,
                [
                    seqExec('rm -rf /home/repogate/repos/'+projName),
                    seqExec('rm -rf /var/tmp/repo_update/'+projName),
                    seqExec(
                        'bash /home/repogate/deploy_rg/es-rm.sh'+
                        ' '+process.env.ES_PASSWORD+
                        ' '+'/home/repogate/repos_pass.aes'+
                        ' '+projName
                    ),
                    function () {
                        resp.writeHead(200, {'Content-Type': 'text/html'});
                        resp.write('<script>document.location="/projects";</script>');
                        resp.end();
                    },
                ],
                function (err) {
                    serverError(resp, err);
                }
            );
        }
    ),
    '/projects/logs': readProject(
        '',
        function (req, resp, projName) {
            fs.readFile('/var/tmp/repo_update/'+projName, 'utf8', function (err, data) {
                if (err) {
                    serverError(resp, err);
                    return;
                }

                resp.write('<pre>'+data+'</pre>');
                resp.end();
            });
        }
    ),
};

function serverError(resp, err) {
    console.log(err);
    resp.writeHead(500, {'Content-Type': 'text/html'});
    resp.write('500 Internal Server Error');
    resp.end();
}

function seq(data, seq, fail) {
    let next = function () {};
    for (let i = seq.length-1; i > 0; i--) {
        let n = next;
        next = function (data) {
            seq[i](data, n, fail);
        }
    }
    seq[0](data, next, fail);
}

function seqExec(cmd) {
    return seqExecInDir(cmd, '/');
}

function seqExecInDir(cmd, dir) {
    return function (data, next, fail) {
        cp.exec(
            cmd,
            {cwd: dir},
            function (err, stdout, stderr) {
                if (err) {
                    fail(err);
                    return;
                }
                next();
            }
        );
    };
};

function readLogs(supPath, subPath) {
    return function (req, resp) {
        var u = url.parse(req.url, true);
        var sess_id = u.query.sess_id;
        if (sess_id) {
            var path = supPath+'/'+sess_id+'/'
            if (subPath.length > 0) {
                path += subPath + '/';
            }
            path += 'log';
            fs.readFile(path, 'utf8', function (err, data_) {
                if (err) {
                    serverError(resp, err);
                    return;
                }
                resp.writeHead(200, {'Content-Type': 'text/html'});
                resp.write("<pre>"+data_+"</pre>");
                resp.end();
            });
        } else {
            readDir(resp, supPath, '', 'sess_id');
        }
    }
};

function readDir(resp, path, text, itemName) {
    fs.readdir(path, function(err, items) {
        if (err) {
            serverError(resp, err);
            return;
        }

        resp.writeHead(200, {'Content-Type': 'text/html'});
        resp.write(text+'<ul>');
        items.forEach(function (item) {
            resp.write(
                '<li>'+
                    '<a href="?'+itemName+'='+item+'">'+
                        item+
                    '</a>'+
                '</li>'
            );
        });
        resp.write('</ul>');
        resp.end();
    });
}

function readProject(text, f) {
    return function (req, resp) {
        var projName = url.parse(req.url, true).query.name;
        if (projName) {
            f(req, resp, projName);
        } else {
            readDir(resp, '/var/tmp/repo_update', text, 'name');
        }
    };
}

var certDir = '/home/repogate/deploy_rg/letsencrypt/live/fixedpointcode.com';
https.createServer(
    {
        key: fs.readFileSync(certDir+'/privkey.pem'),
        cert: fs.readFileSync(certDir+'/cert.pem')
    },
    function (req, resp) {
        var handle = paths[url.parse(req.url).pathname];
        if (handle) {
            handle(req, resp);
        } else {
            resp.writeHead(404 ,{'Content-Type': 'text/plain'});
            resp.write('404 Not Found');
            resp.end();
        }
    }
).listen(8080);
