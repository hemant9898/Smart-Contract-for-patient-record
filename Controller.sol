// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.0;

import "./Shared.sol";

contract Controller {
    // State variables
    address public owner;
    mapping (address => Shared.Patient) public patients;
    mapping (address => Shared.Doctor) public doctors;
    mapping (address => Shared.Oracle) public oracles;
    

    bytes32[] bundleHashes;
    mapping(bytes32 => Shared.Record) records;
    


    
    //Modifier
    modifier notOwner {
        require(msg.sender != owner, "Controller owner account cannot call this function");
        _;
    }

    modifier onlyPatient {
        // require(msg.sender == patient, "Owner patient required");
        require(patients[msg.sender].registered==true,"Owner patient required");
        _;
    }

    modifier onlyDoctor {
        // require(controller.isDoctorRegistered(msg.sender), "Doctor required");
        require(doctors[msg.sender].registered==true,"Doctor required");
        _;
    }
    
    modifier onlyOracle {
        // require(controller.isOracleRegistered(msg.sender), "Oracle required");
        require(oracles[msg.sender].registered==true,"Oracle required");
        _;
    }


    
    modifier onlyNotRegistered {
        require(patients[msg.sender].registered==false, "Unregistered account required");
        require(doctors[msg.sender].registered==false, "Unregistered account required");
        require(oracles[msg.sender].registered==false, "Unregistered account required");
        _;
    }
    
    
    // Constructor
    constructor(){
        owner = msg.sender;
    }

    

    // Add patient
    function addPatient() public onlyNotRegistered notOwner {
        Shared.Patient memory patient;
        patient.registered = true;
        
        patients[msg.sender] = patient;
    }
    
    // Add and check registration doctor
    function addDoctor() public onlyNotRegistered notOwner {
        Shared.Doctor storage doctor;
        doctor.registered = true;
        
        doctors[msg.sender] = doctor;
    }
    
    function isDoctorRegistered(address doctorAddress) view public returns (bool) {
        return doctors[doctorAddress].registered;
    }
    
    // Add and check registration oracles
    function addOracle() public onlyNotRegistered notOwner {
        Shared.Oracle storage oracle;
        oracle.registered = true;
        oracle.averageContractRating = 50;
        oracle.contractRatingCount = 0;
        oracle.averageDoctorRating = 50;
        oracle.doctorRatingCount = 0;
        
        oracles[msg.sender] = oracle;
    }
    
    function isOracleRegistered(address _oracleAddress) view public returns (bool) {
        return oracles[_oracleAddress].registered;
    }
    
    // TODO: maybe add a modifier
    function getOracleReputations(address[] memory _oracleAddresses) view internal returns (uint16[] memory) {
        uint16[] memory reputations = new uint16[](_oracleAddresses.length);

        // NOTE: we are assuming oracleAddresses 
        for (uint16 i = 0; i < _oracleAddresses.length; i++) {
            Shared.Oracle memory oracle = oracles[_oracleAddresses[i]];
            
            reputations[i] = (oracle.averageContractRating + oracle.averageDoctorRating) / 2;
        }
        
        return reputations;
    }
    
    //onlyNotRegistered
    function submitContractOracleRatings(address[] memory _oracleAdresses, uint16[] memory _ratings) internal  view{
        for (uint16 i = 0; i < _oracleAdresses.length; i++) {

            // changing
            Shared.Oracle memory oracle = oracles[_oracleAdresses[i]];
            oracle.averageContractRating = (oracle.contractRatingCount * oracle.averageContractRating + _ratings[i]) / (oracle.contractRatingCount + 1);
            oracle.contractRatingCount += 1;
        }
    }
    
    //onlyNotRegistered
    function submitDoctorToken(address _doctorAddress, bytes32 _tokenID, address _oracleAddress) internal {
        doctors[_doctorAddress].tokenIDs.push(_tokenID);
        doctors[_doctorAddress].tokens.push(Shared.DoctorToken(true, _oracleAddress));
        
    }
    

    //onlyNotRegistered
    function submitOracleToken(address _oracleAddress, bytes32 _tokenID, address _doctorAddress) internal {
        oracles[_oracleAddress].tokenIDs.push(_tokenID);
        oracles[_oracleAddress].tokens.push(Shared.OracleToken(true, _doctorAddress));
        
    }
    
    // TODO: think about the correct modifier here

    event check15(uint16 rating);

    function submitDoctorOracleRating(bytes32 _tokenID, address _oracleAddress, uint16 _rating) public onlyDoctor{
        

        bool dt=false;
        bool ot=false;
        address da;
        address oa;

        for(uint i=0;i<oracles[_oracleAddress].tokenIDs.length;i++){
            if(oracles[_oracleAddress].tokenIDs[i]==_tokenID){
                ot=true;
                da=oracles[_oracleAddress].tokens[i].doctorAddress;
                break;
            }
        }     

        for(uint i=0;i<doctors[msg.sender].tokenIDs.length;i++){
            if(doctors[msg.sender].tokenIDs[i]==_tokenID){
                dt=true;
                oa=doctors[msg.sender].tokens[i].oracleAddress;
                break;
            }
        }    

        require(ot&&dt,"Valid token required");
        require(da==msg.sender&&oa==_oracleAddress,"Valid token required");





        Shared.Oracle memory oracle = oracles[_oracleAddress];
        uint16 newRating=(oracle.contractRatingCount * oracle.averageContractRating + _rating) / (oracle.contractRatingCount + 1);
        oracles[_oracleAddress].averageDoctorRating = newRating;


        emit check15(oracle.averageDoctorRating);
        oracle.doctorRatingCount += 1;
    }


    function getOracleRating(address oracleAdd) public view onlyOracle returns(uint16) {
        return oracles[oracleAdd].averageDoctorRating;
    }







    // PATIENT STARTS:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    // Adding a record (done by patient)
    //new
    event recordAddedPatient(bool flag, bytes32 hashOfRecord); // Inform patient // TODO: finish this // TODO: make sure this is correct (no timeout issues)
    event check1(uint num1);

    
    function addRecord(bytes32 _bundleHash, byte _permissions) public onlyPatient {
        bundleHashes.push(_bundleHash);
        

        //new
        Shared.Record storage newRecord;
        newRecord.permissions = _permissions;
        newRecord.requestCount=0;

        records[_bundleHash] = newRecord;
        

        //new
        emit check1(records[bundleHashes[bundleHashes.length-1]].requestCount);
        emit recordAddedPatient(true,bundleHashes[bundleHashes.length-1]);
    }


    // Request a record (done by doctor)
    // TODO: transaction fees related to _oracleCount
    // TODO: penalize if oracle responded to PRSC but didn't send to doctor

    //new
    event recordRequestedDoctor(bool flag,bytes doctorPublicKey);

    event recordRequestedPatient(bytes doctorPublicKey); // Inform doctor about successful request, and inform patient about new request (must contain doctor's public key)
    event check2(uint num2);
    event check3(uint count);
    event check7(address da);
    event check9(uint length);
    event check10(uint len);
    event check11(uint l);
    function requestRecord(uint16 _recordIndex, bytes memory _publicKey, uint8 _minOracleCount, uint8 _maxOracleCount) public onlyDoctor{
        // require(Shared.checkPublicKey(_publicKey), "Valid public key required");
        // require((uint256(keccak256(_publicKey)) & (0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == uint256(msg.sender), "Valid public key required");
        require( _recordIndex<bundleHashes.length,"No request for this record index");
        require(_minOracleCount <= _maxOracleCount, "_minOracleCount <= _maxOracleCount required");


        //old
        // Shared.Request memory request;
        //new
        Shared.Request storage request;
        request.doctor = msg.sender;
        request.requestTime = block.timestamp;
        request.minOracleCount = _minOracleCount;
        request.maxOracleCount = _maxOracleCount;
        request.grant = false;
        request.oraclesEvaluated = false;




        //old
        uint index=records[bundleHashes[_recordIndex]].requestCount;
        emit check2(index);
        records[bundleHashes[_recordIndex]].requests.push(request);
        emit check7(records[bundleHashes[_recordIndex]].requests[index].doctor);
        records[bundleHashes[_recordIndex]].requestCount+=1;
        emit check3(records[bundleHashes[_recordIndex]].requestCount);
        emit check9(records[bundleHashes[_recordIndex]].requests[index].oracleAddresses.length);
        // records[bundleHashes[_recordIndex]].requests[index].oracleRatings[0]=0;
        delete records[bundleHashes[_recordIndex]].requests[index].oracleRatings;
        emit check11(records[bundleHashes[_recordIndex]].requests[index].oracleRatings.length);
        // emit check10(records[bundleHashes[_recordIndex]].requests[index].oracleRatings[0]);

        
        emit recordRequestedDoctor(true,_publicKey);
        emit recordRequestedPatient(_publicKey);
    }



    // Respond to a pending request (done by patient) // TODO: need more efficient way to track pending requests

    // new
    event requestRespondedPatient(string response);
    event requestRespondedOracles(bytes32 hashOfRecord, bool flag); // TODO: must include bundle hash and so and so
    event check4(bool flag);
    event check12(address da);


    function respondRequest(uint16 _recordIndex, uint16 _requestIndex, bool _grant) public onlyPatient {

        require( _recordIndex<bundleHashes.length,"No request for this record index");
        
        Shared.Record storage record = records[bundleHashes[_recordIndex]];

        require(record.requests.length!=0,"There is not any request for this record");
        require(_requestIndex<record.requests.length,"No request for this request index");

        //old
        records[bundleHashes[_recordIndex]].requests[_requestIndex].grant = _grant;

        
        emit check12(records[bundleHashes[_recordIndex]].requests[_requestIndex].doctor);
        emit requestRespondedPatient("Accsses Granted");
        emit check4(records[bundleHashes[_recordIndex]].requests[_requestIndex].grant);

        if (_grant) {
            // new
            emit requestRespondedOracles(bundleHashes[_recordIndex],true);
        
            // call function after 2 hours
        }
    }


    // Add oracle response (done by oracle)
    // TODO: to think about: what if patient revoked after oracle participated?
    // TODO: maybe let doctor select 1 hours
    // TODO LATER: consider all oracles are bad
    // NOTE:
    /* 
     * There are 3 cases to start evaluating oracles and stop accepting more oracle responses:
     * 1- still waiting for min: reach min then evaluate
     * 2- got min but not max: evaluate on timeout
     * 3- got max: evaluate
     */


    event check5(address da);
    event check6(address oa);
    event check8(bool istrue);
    event check13(uint len);
    event check14(uint pop);
    function OracleResponse(uint16 _recordIndex, uint16 _requestIndex, bytes32 _bundleHash) public onlyOracle {
        require( _recordIndex<bundleHashes.length,"No request for this record index");

        Shared.Record storage record = records[bundleHashes[_recordIndex]];

        
        require(record.requests.length!=0,"There is not any request for this record");
        require(_requestIndex<record.requests.length,"No request for this request index");
        //old
        Shared.Request storage request = record.requests[_requestIndex];
        

        emit check5(request.doctor);
        emit check8(request.grant);
    
        require(request.grant==true, "Granted request required");
        require(!request.oraclesEvaluated, "Unevaluated request required");
        
        uint16 latency = (uint16)(block.timestamp - request.requestTime);
        
        if (request.oracleAddresses.length <= request.minOracleCount ||
            (request.oracleAddresses.length >= request.minOracleCount &&
            request.oracleAddresses.length < request.maxOracleCount &&
            latency <= 1 hours)) {
                
            uint8 isHashCorrect = _bundleHash == bundleHashes[_recordIndex] ? 1 : 0;
                
            // TODO LATER: this should not be bundle hash but rather ks_kPp#
            uint16 input_start = 1;
            uint16 input_end = 3600;
            uint16 output_start = 2**16 - 1;
            uint16 output_end = 1;

            // TODO: make sure this is working correctly
            uint16 oracleRating = isHashCorrect;
            if (latency < 1)
                oracleRating = 2*16 - 1;
                
            else if (latency > 1 hours)
                oracleRating *= 0;
                
            else
                oracleRating *= output_start + ((output_end - output_start) / (input_end - input_start)) * (latency - input_start);

            // TODO: shouldn't be in ledger, directly send to measure reputation
            // request.oracleAddresses.push(msg.sender);


            request.oracleAddresses.push(msg.sender);
            request.oracleRatings.push(oracleRating);
            emit check13(request.oracleRatings[0]);
            emit check6(request.oracleAddresses[request.oracleAddresses.length-1]);
            
            
        }


        
        // if ((request.oracleAddresses.length >= request.minOracleCount && request.requestTime + 1 hours <= block.timestamp) ||
        //     request.oracleAddresses.length == request.maxOracleCount) {
        //     evaluateOracles(_recordIndex, _requestIndex);
        //     request.oraclesEvaluated = true;
        //     uint num=98;
        //     emit check14(num);
        // }
    }


    function EvaluationOfOracles(uint16 _recordIndex, uint16 _requestIndex) public onlyPatient{
        require( _recordIndex<bundleHashes.length,"No request for this record index");

        Shared.Record storage record = records[bundleHashes[_recordIndex]];


        require(record.requests.length!=0,"There is not any request for this record");
        require(_requestIndex<record.requests.length,"No request for this request index");

        Shared.Request storage request = record.requests[_requestIndex];

        if ((request.oracleAddresses.length >= request.minOracleCount && request.requestTime + 1 hours <= block.timestamp) ||
            request.oracleAddresses.length == request.maxOracleCount) {
            evaluateOracles(_recordIndex, _requestIndex);
            request.oraclesEvaluated = true;
            uint num=98;
            emit check14(num);
        }
    }


    
    
    
    event tokenCreatedDoctor(bytes32 tokenID, address oracleAddress); // oracle info
    event tokenCreatedOracle(bytes32 tokenID, address doctorAddress); // doctor info
    function evaluateOracles(uint16 _recordIndex, uint16 _requestIndex)internal {

        Shared.Record storage record = records[bundleHashes[_recordIndex]];

        //old
        Shared.Request storage request = record.requests[_requestIndex];

        request.oraclesEvaluated = true;

        
        // new
        uint16[] memory reputations = getOracleReputations(request.oracleAddresses);
        uint16[] memory ratings = new uint16[](request.oracleAddresses.length);
        
        address bestOracleAddress;
        uint64 bestOracleScore = 0;
        
        for (uint16 i = 0; i < request.oracleAddresses.length; i++) {

            //old
            uint16 oracleRating = uint16(request.oracleRatings[i]);

            

            uint16 oracleReputation = reputations[i];
            
            uint64 oracleScore = oracleRating * (oracleReputation + 1)**2;
            
            if (oracleScore >= bestOracleScore) {
                bestOracleScore = oracleScore;
                bestOracleAddress = request.oracleAddresses[i];
            }
            
            ratings[i] = oracleRating;
        }
        
        submitContractOracleRatings(request.oracleAddresses, ratings);
        
        bytes32 tokenID = keccak256(abi.encodePacked(request.doctor, bestOracleAddress, block.timestamp));
        
        emit tokenCreatedDoctor(tokenID, bestOracleAddress);
        emit tokenCreatedOracle(tokenID, request.doctor);

        submitDoctorToken(request.doctor, tokenID, bestOracleAddress);
        submitOracleToken(bestOracleAddress, tokenID, request.doctor);
        
    }


}
