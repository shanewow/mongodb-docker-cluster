var cfg = { _id: 'set1',
    members: [
        { _id: 0, host: 'mongo-r1s1:27017'},
        { _id: 1, host: 'mongo-r2s1:27017'}
    ]
};

var error = rs.initiate(cfg);
printjson(error);