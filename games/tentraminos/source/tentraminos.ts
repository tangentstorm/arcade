var d3;

var SECONDS = 1000;

var cellsize = 32;
var gw = 9; // grid width: can't have 10 in a row, for obvious reasons :)
var gh = 9; // grid height
var numcells = gw * gh;
var state = {
    clock : 0,
    score : 0,
    paused: false,
    gameOver: false,
    next : 0
}

var clockdiv = d3.select("#clock");
var scorediv = d3.select("#score");
var debugtxt = d3.select("#debugtxt");
var cursor = d3.select("#cursor");
var cells = d3.select("#cells").selectAll("rect")
    .data(d3.range(numcells));
var holddiv = d3.select("#hold").selectAll("rect")
    .data(d3.range(gw));

var colors = [

    "#292929", // 0 almost black
    "#a40000", // 1 dark red
    "#4e9a06", // 2 dark green
    "#c4a000", // 3 dark yellow
    "#204a87", // 4 dark blue
    "#66355f", // 5 dark purple
    "#00a4a2", // 6 dark cyan
    "#ce5c00", // 7 dark orange
    "#888a85", // 8 light gray

    "#3e4446", // 9 dark gray
    "#cc0000", // 10 light red
    "#73d216", // 11 light green
    "#edd400", // 12 light yellow
    "#3465a4", // 13 light blue
    "#8b608b", // 14 light purple
    "#16d2bd", // 15 light cyan
    "#f57900", // 16 light orange
    "#cccccc", // 17 almost white
];

var matrix = [];
var hold = [];

function randCell() {
    return 1 + Math.floor(Math.random() * 8)
}


for (var i = 0; i < numcells; ++i) {
    matrix.push(0);
    hold.push(randCell());
}

cursor.attr({
    x: 4,
    y: 4,
    width: cellsize * 2-8,
    height: cellsize * 2-8,
    "stroke-width": 8,
    "fill-opacity": 0,
    stroke : "black"
});

cells.enter().append("rect");
holddiv.enter().append("rect");

function redraw() {
    cells.attr({
	x: function(i:number){ return cellsize * (i % 9); },
	y: function(i:number){ return cellsize * Math.floor(i/9); },
	opacity: function(i:number){ return matrix[i] == 0 ? 0 : 1 },
	fill: function(i:number){ return colors[matrix[i]] },
	stroke: function(i:number) {
	    return matrix[i] >= 9
		? colors[matrix[i]-9]
		: "black";
	},
	width: cellsize,
	height: cellsize,
    });
    holddiv.attr({
	fill: function(i:number){ return colors[hold[i]] },
	x: function(i:number){ return cellsize * (i % 9); },
	stroke: 'black',
	width: cellsize,
	height: cellsize,

    });
    clockdiv.text(Math.floor(state.clock/SECONDS).toString());
    scorediv.text(state.score.toString());
}


//-- cursor movement ----------------------------

cursor.x = 3;
cursor.y = 7;
cursor.attr({
    x : cursor.x * cellsize + 4,
    y : cursor.y * cellsize + 4 });

function movecursor() {
    cursor.transition().duration(50).attr({
	x : cursor.x * cellsize + 4,
	y : cursor.y * cellsize + 4 });
}
movecursor();

function clamp(val, min, max : number) {
    return val < min ? min
	 : val > max ? max
	 : val;
}

var codes = {
    '^' : ()=> { cursor.y = clamp( cursor.y - 1, 0, 7 ); },
    'v' : ()=> { cursor.y = clamp( cursor.y + 1, 0, 7 ); },
    '<' : ()=> { cursor.x = clamp( cursor.x - 1, 0, 7 ); },
    '>' : ()=> { cursor.x = clamp( cursor.x + 1, 0, 7 ); },
    '(' : ()=> {
	var cxy = cursor.y * gw + cursor.x;
	var tmp = matrix[ cxy ];
	matrix[ cxy          ] = matrix[ cxy + 1      ];  // <
	matrix[ cxy      + 1 ] = matrix[ cxy + gw + 1 ];  // ^
	matrix[ cxy + gw + 1 ] = matrix[ cxy + gw     ];  // >
	matrix[ cxy + gw     ] = tmp;                     // v
    },
    ')' : ()=> {
	var cxy = cursor.y * gw + cursor.x;
	var tmp = matrix[ cxy ];
	matrix[ cxy          ] = matrix[ cxy + gw     ];  // ^
	matrix[ cxy + gw     ] = matrix[ cxy + gw + 1 ];  // <
	matrix[ cxy + gw + 1 ] = matrix[ cxy      + 1 ];  // v
	matrix[ cxy      + 1 ] = tmp;                     // >
    },
    'p' : ()=> { state.paused = !state.paused; }
}


// -- keyboard controls -------------------------

var dvorak = {

    // dvorak layout:
    67 : '^', // c
    72 : '<', // f
    78 : '>', // n
    79 : '(', // o
    80 : 'p', // p
    84 : 'v', // t
    85 : ')', // j

    // for use with arrows:
    88 : ')', // x
    90 : '(', // z

    // wasd:
    87 : '^', // w
    65 : '<', // a
    83 : 'v', // s
    68 : '>', // d
    75 : '(', // k
    76 : ')', // l
}
var keymap = dvorak;


document.onkeydown = function(e) {
    var code = window.event? event.keyCode: e.keyCode;
    if (keymap.hasOwnProperty(code)) codes[keymap[code]]();
    else switch (code) {
	case 37 : codes['<'](); break;
	case 38 : codes['^'](); break;
	case 39 : codes['>'](); break;
	case 40 : codes['v'](); break;
      default:
	console.log('code:', code);
	return true;
    }
    movecursor();
    return false;
}

// -- gravity --------------------------------------------------


function release() {
    for (var i = 0; i < gw; i++) {
	matrix[i] = hold[i];
	hold[i] = 0;
    }
}
function refill() {
    for (var i = 0; i < gw; i++) hold[i] = randCell();
}

// return # of "holes" encountered
function runGravity() {
    var block = gw * (gh-2) + gw-1;
    var below = block + gw;
    var cxy = cursor.y * gw + cursor.x;
    var result = 0;

    for (var y = gh-2; y >= 0; y--)
    for (var x = gw-1; x >= 0; x--) {

	// the cursor can hold blocks in the air
	if ((block == cxy) ||
	    (block == cxy + 1) ||
	    (block == cxy + gw) ||
	    (block == cxy + gw + 1)) {
	    // pass
	} else if (! matrix[below]) {
	    if (matrix[block]) result++;
	    matrix[below] = matrix[block];
	    matrix[block] = 0;
	}
	block--; below--;
    }
    return result;
}

// -- floodfind ------------------------------------------------

function xy2i(x,y:number) {
    return y * gw + x;
}

function findshapes() {
    var result = [];
    var startx = 0;
    var starty = 0;
    var groups = new Uint32Array((gh+2) * (gw+2));
    var count = 1;
    var maxx = gw-1;
    var maxy = gh-1;

    function floodfind(x, y, shape, color, group) {
	var i = xy2i(x,y);
	if (groups[i]==0 && matrix[i]==color) {
	    groups[i] = group;
	    shape.push(xy2i(x,y));
	    if (x > 0)    floodfind(x-1, y, shape, color, group);
	    if (x < maxx) floodfind(x+1, y, shape, color, group);
	    if (y > 0)    floodfind(x, y-1, shape, color, group);
	    if (y < maxy) floodfind(x, y+1, shape, color, group);
	}
	return shape;
    }

    for (var y = 0; y < gh; y++ )
	for (var x = 0; x < gw; x++ ) {
	    var i = xy2i(x, y);
	    if (matrix[i] && matrix[i] < 9 && !groups[i]) {
		result.push(floodfind(x, y, [], matrix[i], count++));
	    }
	}

    return result;
}

function markshapes() {
    for (var i = 0; i < matrix.length; i++) {
	if (matrix[i] > 8) { matrix[i] -= 9; }
    }
    var shapes = findshapes();
    for (var i = 0; i < shapes.length; i++) {
	var shape = shapes[i];
	if (shape.length >= 4) {
	    for (var j = 0; j < shape.length; j++) {
		var xy = shape[j];
		if (matrix[xy] < 9) matrix[xy] += 9;
	    }
	}
    }
    return shapes;
}

function clearshapes() {
    var shapes = markshapes();
    for (var i = 0; i < shapes.length; i++) {
	switch (shapes[i].length) {
	    case 1: break;
	    case 2: break;
	    case 3: break;
	default:
	    state.score += 10*Math.pow(2, shapes[i].length-4);
	    for (var j = 0; j<shapes[i].length; j++) {
		var xy = shapes[i][j];
		matrix[xy] = 0;
	    }
	}
    }
}

// -- game over ------------------------------------------------

function checkGameOver() {
    var result = false;
    for (var i = 0; i < gw; i++) {
	if (matrix[i] != 0) result = true;
    }
    state.gameOver = result;
    return result;
}

// -- counter --------------------------------------------------

function now() { // current time in ms
    return new Date().getTime();
}

var clock = { start: now() };

var NEWGAME = 0,
    PLAYING = 1,
    PAUSED  = 2,
    TIMEUP  = 3,
    THEEND  = 4,
    NEXTROUND=5,
    CASCADE  =6,
    CHECK4END=7;

state.next = NEWGAME;

function step(dt:number) {
//    debugtxt.text(state.next.toString());

    switch (state.next) {

    case NEWGAME:
	refill();
	release();
	redraw();
	return CASCADE;

    case NEXTROUND:
	refill();
	redraw();
	state.clock = 10 * SECONDS;
	return PLAYING;

    case PLAYING:
	state.clock -= dt;
	runGravity();
	markshapes();
	redraw();
	return (state.paused)     ? PAUSED
	     : (state.clock <= 0) ? TIMEUP
				  : PLAYING;

    case PAUSED:
	return (state.paused) ? PAUSED : PLAYING;

    case TIMEUP:
	state.clock = 0;
	release();
	clearshapes();
	redraw();
	return CASCADE;

    case CASCADE:
	var count = runGravity();
	redraw();
	return count ? CASCADE : CHECK4END;

    case CHECK4END:
	return checkGameOver() ? THEEND : NEXTROUND;

    case THEEND:
	return THEEND;
    }
}

var lastTick = now();
function tick() {
    var thisTick = now();
    var dt = thisTick - lastTick;
    state.next = step(dt);
    lastTick = thisTick;
}
window.setInterval(tick, 100);
