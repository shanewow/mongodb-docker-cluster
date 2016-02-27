var cfg = { _id: 'set3',
    members: [
        { _id: 0, host: 'mongo-r1s3:27017'},
        { _id: 1, host: 'mongo-r2s3:27017'}
    ]
};

var error = rs.initiate(cfg);
printjson(error);