package dn.heaps;

#if !heaps
#error "Heaps is required"
#end

/**
	A fast display object containing a grid of colored squares
**/
class PixelGrid extends h2d.Object {
	/** Width in cells **/
	public var wid(default,null) : Int;

	/** Height in cells **/
	public var hei(default,null) : Int;

	public var gridSize(default,set) : Int;

	var tg : h2d.TileGroup;
	var pixelTile : h2d.Tile;
	var pixels : Map<Int,Int> = new Map();
	var invalidated = true;

	public function new(gridSize:Int, wid:Int, hei:Int, ?parent:h2d.Object) {
		super(parent);

		this.wid = wid;
		this.hei = hei;

		pixelTile = h2d.Tile.fromColor(0xffffff, 1, 1);
		tg = new h2d.TileGroup(pixelTile, this);

		this.gridSize = gridSize;
	}

	inline function isValid(x,y) return x>=0 && x<wid && y>=0 && y<hei;
	inline function coordId(x,y) return x + y*wid;


	/** Fill a pixel **/
	public inline function setPixel(x:Int, y:Int, rgb:Int, alpha=1.0) {
		if( alpha>0 )
			setPixelMap(x,y, Color.addAlphaF(rgb,alpha));
		else
			removePixelMap(x,y);
	}

	/** Clear a pixel **/
	public inline function removePixel(x:Int, y:Int) {
		removePixelMap(x,y);
	}

	/** Fill a rectangle **/
	public inline function fillRect(x, y, w:Int, h:Int, rgb:Int, alpha=1.0) {
		var c = Color.addAlphaF(rgb, alpha);
		for(y in y...y+h)
		for(x in x...x+w)
			if( alpha>0 )
				setPixelMap(x,y, c);
			else
				removePixelMap(x,y);
	}

	/** Fill all pixels **/
	public inline function fill(rgb:Int, alpha=1.0) {
		var c = Color.addAlphaF(rgb, alpha);
		for(y in 0...hei)
		for(x in 0...wid)
			if( alpha>0 )
				setPixelMap(x,y, c);
			else
				removePixelMap(x,y);
	}


	public inline function line(x1:Int, y1:Int, x2:Int, y2:Int, c:UInt, a=1.0) {
		Bresenham.iterateThinLine( x1,y1,x2,y2, (x,y)->setPixel(x,y, c, a) );
	}

	public inline function lines(pts:Array<{x:Int, y:Int}>, c:UInt, a=1.0, loop=false) {
		if( pts.length>=2 ) {
			for(i in 1...pts.length+1)
				Bresenham.iterateThinLine(
					pts[i-1].x, pts[i-1].y,
					pts[i].x, pts[i].y,
					(x,y)->setPixel(x,y, c, a)
				);

			if( loop )
				Bresenham.iterateThinLine(
					pts[0].x, pts[0].y,
					pts[pts.length-1].x, pts[pts.length-1].y,
					(x,y)->setPixel(x,y, c, a)
				);
		}
	}


	inline function set_gridSize(g:Int) {
		tg.scaleX = tg.scaleY = g;
		return gridSize = g;
	}

	/** Clear all pixels **/
	public function clear() {
		pixels = new Map();
		tg.clear();
		invalidated = true;
	}

	/** Return TRUE if any pixel is set here **/
	public inline function hasPixel(x:Int, y:Int) {
		return isValid(x,y) && pixels.exists( coordId(x,y) );
	}

	/** Return pixel color without alpha (`0xrrggbb`) **/
	public inline function getPixelRGB(x:Int, y:Int) {
		return isValid(x,y) && pixels.exists( coordId(x,y) ) ? Color.removeAlpha( pixels.get( coordId(x,y) ) ) : 0x0;
	}

	/** Return pixel color including alpha (`0xaarrggbb`) **/
	public inline function getPixelARGB(x:Int, y:Int) {
		return isValid(x,y) && pixels.exists( coordId(x,y) ) ? pixels.get( coordId(x,y) ) : 0x0;
	}


	inline function removePixelMap(x:Int, y:Int) {
		if( isValid(x,y) ) {
			invalidated = true;
			pixels.remove( coordId(x,y) );
		}
	}

	inline function setPixelMap(x:Int, y:Int, argb:Int) {
		if( isValid(x,y) ) {
			invalidated = true;
			pixels.set( coordId(x,y), argb );
		}
	}

	/** Optimize and render **/
	override function sync(ctx:h2d.RenderContext) {
		if( invalidated ) {
			// Try to detect rectangles of identical contiguous pixels
			var c = 0;
			var w = 0;
			var h = 0;
			var dx = 0;
			var dones = new Map();
			var same = true;
			for(y in 0...hei)
			for(x in 0...wid) {
				if( hasPixel(x,y) && !dones.exists( coordId(x,y) ) ) {
					dones.set( coordId(x,y), true );
					c = pixels.get( coordId(x,y) );
					w = 1;
					// Expand horizontally
					while( isValid(x+w,y) && getPixelARGB(x+w, y)==c && !dones.exists( coordId(x+w,y) ) ) {
						dones.set(coordId(x+w, y), true);
						w++;
					}
					// Expand vertically
					h = 1;
					while( isValid(x,y+h) && pixels.get(coordId(x,y+h))==c ) {
						dx = 0;
						same = true;
						while( dx<w && isValid(x+dx,y+h) ) {
							if( pixels.get(coordId(x+dx, y+h))!=c ) {
								same = false;
								break;
							}
							dx++;
						}

						if( same ) {
							for(x in x...x+w)
								dones.set(coordId(x, y+h), true);
							h++;
						}
						else
							break;
					}

					// Fill rect
					tg.setDefaultColor( c, Color.getA(c) );
					tg.addTransform( x, y, w, h, 0, pixelTile );
				}
			}

			invalidated = false;
		}

		super.sync(ctx);
	}
}