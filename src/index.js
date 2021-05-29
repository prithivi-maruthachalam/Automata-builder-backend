const express = require('express')
const cors = require('cors')
const bodyParser = require('body-parser')
const mysql = require('mysql')
const crypto = require('crypto')
const util = require('util')
const dbOptions = require('./config.js')

const server = express()
server.use(cors())
server.use(bodyParser.urlencoded({ extended: false }))
server.use(bodyParser.json())

console.clear()

// constants
const port = 3000

// database 
const con = mysql.createConnection(dbOptions)

const dbConQuery = util.promisify(con.query).bind(con)

con.connect((err) => {
    if (err) {
        console.error("HEY WE GOT AN ERROR")
        throw err
    }
    console.log("Connected to MySQL server")
})

// endpoints
server.post('/newMachine', async (req, res) => {
    console.debug("\nReceived POST on /newMachine")
    try {
        let stateMachine = req.body.body.machine
        let machineName = req.body.body.name
        const machineHash = crypto.createHmac("sha256", machineName).update(JSON.stringify(stateMachine)).digest("binary")

        // check if the machine has any content
        if (stateMachine.length < 1) {
            console.log('Machine is empty')
            res.status(400).send('Empty machine')
            return false
        }

        // create the base query
        let query = "INSERT into machines (machineID, machineName, stateID, stateType, alphabet, toState, rowID) values "
        let insertGroup = ""
        let valuesFormat = "(?,?,?,?,?,?,?)"

        let i = 1

        // for each state and for each transition add the relevant values to the query
        stateMachine.forEach(async (state,machineIndex) => {
            const stateID = 'q' + state.state
            let rowID = (machineIndex + 1 == stateMachine.length) ? -1 : i
            if (stateMachine.length <= 1) {
                rowID = -2
            }
            // if this a state that doesn't have any transitions going out, just make the transitions null
            if (state.transitions.length < 1) {
                let insert = mysql.format(valuesFormat, [machineHash, machineName, stateID, state.stateType, null, null,rowID])
                insertGroup = (insertGroup != "") ? [insertGroup, insert].join(" , ") : insert
                i++
            }
            
            state.transitions.forEach((transition, transitionIndex) => {
                const toStateID = 'q' + transition.toState
                let rowID = ((machineIndex + 1 == stateMachine.length) && (transitionIndex + 1 == state.transitions.length)) ? -1 : i;
                if (stateMachine.length <= 1) {
                    rowID = -2    
                }
                let insert = mysql.format(valuesFormat, [machineHash,
                    machineName,
                    stateID,
                    state.stateType,
                    transition.alphabet,
                    toStateID,
                    rowID
                ])
                insertGroup = (insertGroup != "") ? [insertGroup, insert].join(" , ") : insert
                i++
            });
        });

        query = [query, insertGroup].join("")
        console.log(`Sending query to hut8: ${query}`)

        const response = await dbConQuery(query)
        if (response.affectedRows > 0) {
            res.status(200).send(machineHash)
        } else {
            res.status(500).send(false)
        }

    } catch (err) {
        if (err.sqlMessage) {
            console.log(err.sqlMessage)
            res.status(400).send(err.sqlMessage)
        } else {
            res.status(500).send(false)
        }
    }
})

server.post('/runMachine',async (req, res) => {
    console.debug("\nReceived request on /runMachine")
    try {
        const machineHash = req.body.body.hash 
        const testString = req.body.body.test
        
        let query = 'CALL run_machine(?, ?, @result)'
        query = mysql.format(query, [testString, machineHash])
        console.log(`Sending query to hut8: ${query}`)


        const response = await dbConQuery(query)
        if (response.affectedRows > 0) {
            const result = await dbConQuery("SELECT @result")
            res.status(200).send((result[0]['@result'] == 1) ? true : false)
        } else {
            res.status(500).send(false)
        }

    } catch(err) {
        if (err.sqlMessage) {
            console.log(err.sqlMessage)
            res.status(400).send(err.sqlMessage)
        } else {
            res.status(500).send(false)
        }
    }
})

server.listen(port, () => {
    console.log(`Mathison is listening on port ${port}`)
}).on('error', (err) => {
    console.log(err)
    console.log('Stopping server')
    process.exit(1)
})

