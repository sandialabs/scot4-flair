function list(type) {
    window.location.href = "/flair/dt/"+type;
}

function create_new(type) {
    window.location.href = "/flair/new/"+type;
}

function buildJsonData(columns) {
    let jsonData = {};
    for (const n of columns) {
        jsonData[n] = document.getElmentById(n).value;
    }
    return jsonData;
}

function put(type, element_id, columns) {
    const id = document.getElementById(element_id).value;
    const url = '/api/v1/'+type+'/'+id;
    let jsonData = buildJsonData(columns);
    fetch(url, {
        method: 'PUT',
        mode: 'same-origin',
        cache: 'no-cache',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        redirects: 'follow',
        body: JSON.stringify(jsonData)
    }).then((data) => {
        console.log(data);
        location.reload();
    });
}

function del(type, element_id) {
    const id = document.getElementById(element_id).value;
    const url = '/api/v1/'+type+'/'+id;
    fetch(url, {
        method: 'DELETE',
        mode: 'same-origin',
        cache: 'no-cache',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        redirect: 'follow',
    }).then((data) => {
        console.log(data);
        list(type);
    });
}

function post(type, columns) {
    const url = "/api/v1/"+type;
    let jsonData    = buildJsonData(columns);
    fetch(url, {
        method: 'POST',
        mode: 'same-origin',
        cache: 'no-cache',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        redirect: 'follow',
        body: JSON.stringify(jsonData)
    }).then((data) => {
        console.log(data);
        window.location.href = "/flair/dt/"+type;
    });
}
