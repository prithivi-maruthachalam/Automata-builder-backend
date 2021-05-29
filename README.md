# REST API for Automata-Builder
#### This is the backend/REST API + mysql database for the Automata-Builder project. The [front end](https://github.com/prithivi-maruthachalam/Automata-builder-frontend.git) for the project is a Vue based drag-and-drop tool for building Finite Automata


## Note!
#### This project is designed to use a MySQL database. The server expects that the mysql connection information is exported from inside a config.js inside the src/ folder.

## API endpoints
- ### POST:/newMachine
  - @machine : is the machine object from the front end
  - @name : is a user entered name for the machine
  - On success, returns a hmac for the machine object and the name
- ### POST:/runMachine
  - @hash : hash that was returned by the first end point
  - @test : a string to run the machine on
  - On success returns true/false based on the test string being accepted / not accepted by the machine 




