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

package weave.visualization.layers
{
	import flash.geom.Point;
	
	import mx.containers.Canvas;
	
	import weave.api.core.ILinkableObject;
	import weave.api.getCallbackCollection;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.setSessionState;
	import weave.api.ui.IPlotLayer;
	import weave.compiler.MathLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableNumber;
	import weave.core.UIUtils;
	import weave.primitives.Bounds2D;
	import weave.primitives.LinkableBounds2D;
	import weave.primitives.ZoomBounds;
	import weave.utils.SpatialIndex;
	import weave.utils.ZoomUtils;

	/**
	 * This is a container for a list of PlotLayers
	 * 
	 * @author adufilie
	 */
	public class PlotLayerContainer extends Canvas implements ILinkableObject
	{
		public function PlotLayerContainer()
		{
			super();
			init();
		}
		private function init():void
		{
			this.horizontalScrollPolicy = "off";
			this.verticalScrollPolicy = "off";

			autoLayout = true;
			percentHeight = 100;
			percentWidth = 100;
			
			UIUtils.linkDisplayObjects(this, layers);
			
			layers.childListCallbacks.addImmediateCallback(this, handleLayersListChange);
		}
		
		public const layers:LinkableHashMap = registerLinkableChild(this, new LinkableHashMap(IPlotLayer));
		public const zoomBounds:ZoomBounds = newLinkableChild(this, ZoomBounds, updateZoom, false);
		public const marginRight:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0), updateZoom, true);
		public const marginLeft:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0), updateZoom, true);
		public const marginTop:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0), updateZoom, true);
		public const marginBottom:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0), updateZoom, true);
		public const minScreenSize:LinkableNumber = registerLinkableChild(this, new LinkableNumber(128), updateZoom, true);
		public const minZoomLevel:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0), updateZoom, true);
		public const maxZoomLevel:LinkableNumber = registerLinkableChild(this, new LinkableNumber(16), updateZoom, true);
		public const enableFixedAspectRatio:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), updateZoom, true);
		public const enableAutoZoomToExtent:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true), updateZoom, true);
		public const includeNonSelectableLayersInAutoZoom:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), updateZoom, true);

		protected function handleLayersListChange():void
		{
			var oldLayer:IPlotLayer = layers.childListCallbacks.lastObjectRemoved as IPlotLayer;
			if (oldLayer)
			{
				(oldLayer.spatialIndex as SpatialIndex).removeCallback(spatialCallback);
				oldLayer.plotter.spatialCallbacks.removeCallback(spatialCallback);
			}
			var newLayer:IPlotLayer = layers.childListCallbacks.lastObjectAdded as IPlotLayer;
			if (newLayer)
			{
				newLayer.name = layers.childListCallbacks.lastNameAdded; // for debugging
				(newLayer.spatialIndex as SpatialIndex).addImmediateCallback(this, spatialCallback);
				newLayer.plotter.spatialCallbacks.addImmediateCallback(this, spatialCallback);
			}
			if (!oldLayer && !newLayer)
				return;
			
			if (oldLayer || newLayer)
				spatialCallback();
			
			// make sure new layer has correct screenBounds
			// and make sure dataBounds is updated to include new layer
			updateZoom();
		}
		
		private function spatialCallback():void
		{
			updateFullDataBounds();

			// since fullDataBounds (may have) changed, there are new constraints on the dataBounds
			updateZoom();
		}
		
		protected function updateZoom():void
		{
			var layer:IPlotLayer;
			var plotLayer:PlotLayer;
			var selectablePlotLayer:SelectablePlotLayer;
			
			// calculate new screen bounds in temp variable
			// default behaviour is to set screenBounds beginning from lower-left corner and ending at upper-right corner
			var left:Number = marginLeft.value;
			var top:Number = marginTop.value;
			var right:Number = unscaledWidth - marginRight.value;
			var bottom:Number = unscaledHeight - marginBottom.value;
			// set screenBounds beginning from lower-left corner and ending at upper-right corner
			//TODO: is other behavior required?
			tempScreenBounds.setBounds(left, bottom, right, top);
			if (left > right)
				tempScreenBounds.setWidth(0);
			if (top > bottom)
				tempScreenBounds.setHeight(0);
			// copy current dataBounds to temp variable
			zoomBounds.getDataBounds(tempDataBounds);
			
			// determine if dataBounds should be zoomed to fullDataBounds
			if (enableAutoZoomToExtent.value || tempDataBounds.isUndefined())
			{
				if (!fullDataBounds.isEmpty())
				{
					tempDataBounds.copyFrom(fullDataBounds);
					if (enableFixedAspectRatio.value)
					{
						var xScale:Number = tempDataBounds.getWidth() / tempScreenBounds.getXCoverage();
						var yScale:Number = tempDataBounds.getHeight() / tempScreenBounds.getYCoverage();
						// keep greater data-to-pixel ratio because we want to zoom out if necessary
						if (xScale > yScale)
							tempDataBounds.setHeight(tempScreenBounds.getYCoverage() * xScale);
						if (yScale > xScale)
							tempDataBounds.setWidth(tempScreenBounds.getXCoverage() * yScale);
					}
				}
			}
			
			if (!tempScreenBounds.isEmpty())
			{
				var minSize:Number = Math.min(minScreenSize.value, tempScreenBounds.getXCoverage(), tempScreenBounds.getYCoverage());
				
				if (!tempDataBounds.isUndefined() && !fullDataBounds.isUndefined())
				{
					// Enforce pan restrictions on tempDataBounds.
					// Center of visible dataBounds should be a point inside fullDataBounds.
					fullDataBounds.constrainBoundsCenterPoint(tempDataBounds);
				}
			}
			
			// save new screenBounds
			zoomBounds.setBounds(tempDataBounds, tempScreenBounds, enableFixedAspectRatio.value);
			// set new bounds for each layer
			for each (layer in layers.getObjects(IPlotLayer))
			{
				layer.setDataBounds(tempDataBounds);
				
				plotLayer = layer as PlotLayer;
				if (plotLayer && !plotLayer.lockScreenBounds)
					plotLayer.setScreenBounds(tempScreenBounds);
				
				selectablePlotLayer = layer as SelectablePlotLayer;
				if (selectablePlotLayer && !selectablePlotLayer.lockScreenBounds)
					selectablePlotLayer.setScreenBounds(tempScreenBounds);
			}
		}
		
		protected function updateFullDataBounds():void
		{
			tempBounds.copyFrom(fullDataBounds);
			fullDataBounds.reset();
			var _layers:Array;
			if (includeNonSelectableLayersInAutoZoom.value)
				_layers = layers.getObjects(IPlotLayer);
			else
				_layers = layers.getObjects(SelectablePlotLayer); // only consider SelectablePlotLayers
			for each (var plotLayer:IPlotLayer in _layers)
			{
				var spl:SelectablePlotLayer = plotLayer as SelectablePlotLayer;
				if (spl && !spl.layerIsVisible.value)
					continue;
				var pl:PlotLayer = plotLayer as PlotLayer;
				if (pl && !pl.layerIsVisible.value)
					continue;
				
				//trace(layers.getName(plotLayer), plotLayer.spatialIndex.collectiveBounds);
				fullDataBounds.includeBounds((plotLayer.spatialIndex as SpatialIndex).collectiveBounds);
				var bg:IBounds2D = plotLayer.plotter.getBackgroundDataBounds();
				fullDataBounds.includeBounds(bg);
			}
			if (!tempBounds.equals(fullDataBounds))
				getCallbackCollection(this).triggerCallbacks();
		}
		
		/**
		 * This is the collective data bounds of all the selectable plot layers.
		 */
		public const fullDataBounds:IBounds2D = new Bounds2D();
		
		public function getZoomLevel():Number
		{
			zoomBounds.getDataBounds(tempDataBounds);
			zoomBounds.getScreenBounds(tempScreenBounds);
			var useXCoordinates:Boolean = (fullDataBounds.getXCoverage() > fullDataBounds.getYCoverage()); // fit full extent inside min screen size
			var minSize:Number = Math.min(minScreenSize.value, tempScreenBounds.getXCoverage(), tempScreenBounds.getYCoverage());
			var zoomLevel:Number = ZoomUtils.getZoomLevel(tempDataBounds, tempScreenBounds, fullDataBounds, minSize, useXCoordinates);
			return zoomLevel;
		}
		
		public function setZoomLevel(newZoomLevel:Number):void
		{
			var currentZoomLevel:Number = getZoomLevel();
			var newConstrainedZoomLevel:Number = MathLib.constrain(newZoomLevel, minZoomLevel.value, maxZoomLevel.value);
			if (newConstrainedZoomLevel != currentZoomLevel)
			{
				var scale:Number = 1 / Math.pow(2, newConstrainedZoomLevel - currentZoomLevel);
				if (!isNaN(scale) && scale != 0)
				{
					zoomBounds.getDataBounds(tempDataBounds);
					tempDataBounds.setWidth(tempDataBounds.getWidth() * scale);
					tempDataBounds.setHeight(tempDataBounds.getHeight() * scale);
					zoomBounds.setDataBounds(tempDataBounds);
				}
			}
		}
		
		public function invalidateGraphics():void
		{
			for each (var plotLayer:IPlotLayer in layers.getObjects(IPlotLayer))
			{
				plotLayer.invalidateGraphics();
			}
		}
		
		/**
		 * This function checks if the unscaled size of the UIComponent changed.
		 * If so, the graphics are invalidated.
		 * If the graphics are invalid, this function will call validateGraphics().
		 * This is the only function that should call validateGraphics() directly.
		 */
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			// detect size change
			var sizeChanged:Boolean = _prevUnscaledWidth != unscaledWidth || _prevUnscaledHeight != unscaledHeight;
			_prevUnscaledWidth = unscaledWidth;
			_prevUnscaledHeight = unscaledHeight;
			if (sizeChanged)
				updateZoom();
			
			super.updateDisplayList(unscaledWidth, unscaledHeight);
		}
		
		// these variables are used to detect a change in size
		private var _prevUnscaledWidth:Number = 0;
		private var _prevUnscaledHeight:Number = 0;
		
		private const tempPoint:Point = new Point();
		private const tempBounds:IBounds2D = new Bounds2D();
		private const tempScreenBounds:IBounds2D = new Bounds2D();
		private const tempDataBounds:IBounds2D = new Bounds2D();
		
		// backwards compatibility
		[Deprecated(replacement="zoomBounds")] public function set dataBounds(value:Object):void
		{
			setSessionState(zoomBounds, value);
		}
	}
}
