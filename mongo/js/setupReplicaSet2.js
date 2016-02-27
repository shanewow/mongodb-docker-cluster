var cfg = { _id: 'set2',
    members: [
        { _id: 0, host: 'mongo-r1s2:27017'},
        { _id: 1, host: 'mongo-r2s2:27017'}
    ]
};

var error = rs.initiate(cfg);
printjson(error);