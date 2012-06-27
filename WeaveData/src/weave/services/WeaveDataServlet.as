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

package weave.services
{
	import mx.rpc.AsyncToken;
	
	import weave.api.data.IQualifiedKey;
	import weave.api.registerDisposableChild;
	import weave.api.services.IWeaveDataService;
	import weave.api.services.IWeaveGeometryTileService;
	import weave.utils.HierarchyUtils;
	
	/**
	 * This is a wrapper class for making asynchronous calls to a Weave data servlet.
	 * 
	 * @author adufilie
	 */
	public class WeaveDataServlet implements IWeaveDataService
	{
		public function WeaveDataServlet(url:String)
		{
			servlet = new AMF3Servlet(url);
			registerDisposableChild(this, servlet);
		}
		protected var servlet:AMF3Servlet;

		public function getDataServiceMetadata():AsyncToken
		{
			return servlet.invokeAsyncMethod("getDataServiceMetadata", null);
		}

		public function getRows(keys:Array):AsyncToken
		{
			var keysArray:Array = [];
			for each( var key:IQualifiedKey in keys)
			{
				keysArray.push(key.localName);
			}
			var keytype:String = (keys[0] as IQualifiedKey).keyType;
			return servlet.invokeAsyncMethod("getRows",[keytype,keysArray]);
		}
		
		public function getDataTableMetadata(dataTableName:String):AsyncToken
		{
			return servlet.invokeAsyncMethod("getDataTableMetadata", arguments);
		}
		
		public function getAttributeColumn(pathInHierarchy:XML):AsyncToken
		{
			var node:XML = HierarchyUtils.getLeafNodeFromPath(pathInHierarchy) || <empty/>;

			var params:Object = new Object();
			for each (var attr:String in ['dataTable', 'name', 'year', 'min', 'max', 'sqlParams']) // only use these properties for querying
			{
				var value:String = node.attribute(attr);
				if (value != '')
					params[attr] = value;
			}
			
			return servlet.invokeAsyncMethod("getAttributeColumn", params);
		}
		
		public function getAttributeColumnFromMetadata(Metadata:Object):AsyncToken
		{
			return servlet.invokeAsyncMethod("getAttributeColumn", arguments);
		}
		
		// async result is a GeometryStreamMetadata object
		public function getTileDescriptors(geometryCollectionName:String):AsyncToken
		{
			return servlet.invokeAsyncMethod("getGeometryStreamTileDescriptors", arguments);
		}
		// async result is a ByteArray
		public function getMetadataTiles(geometryCollectionName:String, tileIDs:Array):AsyncToken
		{
			return servlet.invokeAsyncMethod("getGeometryStreamMetadataTiles", arguments);
		}
		// async result is a ByteArray
		public function getGeometryTiles(geometryCollectionName:String, tileIDs:Array):AsyncToken
		{
			return servlet.invokeAsyncMethod("getGeometryStreamGeometryTiles", arguments);
		}
		
		public function createTileService(geometryCollectionName:String):IWeaveGeometryTileService
		{
			return registerDisposableChild(this, new WeaveGeometryTileServlet(this, geometryCollectionName));
		}

		public function createReport(name:String, keys:Array):AsyncToken
		{
			return servlet.invokeAsyncMethod("createReport", arguments);
		}
	}
}
