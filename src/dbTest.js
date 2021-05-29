var mysql = require('mysql')

var con = mysql.createConnection({
    host: "localhost",
    user: "automata_admin",
    password: "Nf~He^7EtDMW^t$2",
    database: "automataDB"
})

con.connect((err) => {
    if (err) throw err
    console.log("Connected to DB")
})

con.end()