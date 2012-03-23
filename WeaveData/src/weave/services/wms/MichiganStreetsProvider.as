/*
Weave (Web-based Analysis and Visualization Environment)
Copyright (C) 2008-2011 University of Massachusetts Lowell

This file is a part of Weave.

Weave is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License, Version 3,
as published by the Free Software Foundation.

Weave is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.services.wms
{
	import com.modestmaps.core.Coordinate;
	import com.modestmaps.mapproviders.AbstractMapProvider;
	import com.modestmaps.mapproviders.IMapProvider;
	import com.modestmaps.mapproviders.OpenStreetMapProvider;
	
	import weave.api.services.IWMSService;
	
	/**
	 * This class is simply another provider to be used with ModestMaps library.
	 * MapQuest tile URLs are identical to those used by OpenStreetMap, except for the beginning
	 * of the URL.
	 * 
	 * @author kmonico
	 */
	public class MichiganStreetsProvider extends AbstractMapProvider implements IMapProvider
	{
		public function MichiganStreetsProvider(projection:String, minZoom:int = MIN_ZOOM, maxZoom:int = MAX_ZOOM)
		{
			super(minZoom, maxZoom);
			this.projection = projection;
		}
		
		public function toString():String
		{
			return "CRI";
		}
		
		public static const IMAGE_PROJECTION_SRS_4326:String = "EPSG:4326";
		public static const IMAGE_PROJECTION_SRS_3857:String = "EPSG:3857";
		private var projection:String;
		
		private var serverNumber:int = Math.min(Math.floor(1 + Math.random() * 4), 4);
		public function getTileUrls(coord:Coordinate):Array
		{
			var sourceCoord:Coordinate = sourceCoordinate(coord);
			// /path/to/tiles/z/x/y.png
			// return [ 'http://otile' + serverNumber + '.mqcdn.com/tiles/1.0.0/osm/' + sourceCoord.zoom + '/' 
			//+ sourceCoord.column + '/' + sourceCoord.row + '.png' ];
			
			/* fullRequestString = "http://maps1.cridata.org/py/ogcserver/criWMS.py?SERVICE=WMS&VERSION=1.1.1"
			+ "&REQUEST=GetMap&BBOX="+_requestURLParams[15]+"&SRS=EPSG:4326"
			+ "&WIDTH="+_imageWidth+"&HEIGHT="+_imageHeight+"&LAYERS=michigan_highway&STYLES=&FORMAT=image/png&DPI=72&TRANSPARENT=true"; */
			
			var baseURL:String = "http://maps1.cridata.org/py/tilecache-2.11/tilecache.cgi/1.0.0/osm-michigan-streets";
			if (projection == IMAGE_PROJECTION_SRS_3857)
				baseURL += '-3857';
			var urlString:String = baseURL + "/" + sourceCoord.zoom + '/' + sourceCoord.column + '/' + sourceCoord.row + '.png';
			
			trace("***********************************");
			trace("Zoom: " + sourceCoord.zoom);
			trace("Column: " + sourceCoord.column);
			trace("Row: " + sourceCoord.row);
			trace("All: " + sourceCoord);
			trace("      ");
			trace("Url: " + urlString);
			trace("***********************************");
			
			return [ urlString ];
			
		}
	}
}