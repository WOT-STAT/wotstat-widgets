package wotstat.cef {
  import net.wg.infrastructure.base.AbstractView;
  import net.wg.infrastructure.interfaces.IView;
  import net.wg.infrastructure.events.LoaderEvent;
  import net.wg.data.Aliases;
  import net.wg.gui.lobby.hangar.Hangar;
  import net.wg.infrastructure.managers.impl.ContainerManagerBase;
  import net.wg.data.constants.generated.LAYER_NAMES;
  import net.wg.gui.components.containers.MainViewContainer;
  import scaleform.clik.events.ResizeEvent;
  import flash.events.Event;
  import flash.utils.ByteArray;

  public class MainView extends AbstractView {


    public var py_log:Function;
    public var py_requestResize:Function;
    public var py_requestReload:Function;
    public var py_requestClose:Function;


    private var hangarView:Hangar = null;
    private var activeWidgets:Vector.<DraggableWidget> = new Vector.<DraggableWidget>();
    private var activeWidgetsByUUID:Object = new Object();

    public function MainView() {
      super();
    }

    override protected function configUI():void {
      super.configUI();

      var viewContainer:MainViewContainer = App.containerMgr.getContainer(LAYER_NAMES.LAYER_ORDER.indexOf(LAYER_NAMES.VIEWS)) as MainViewContainer;
      if (viewContainer != null) {
        var num:int = viewContainer.numChildren;
        for (var idx:int = 0; idx < num; ++idx) {
          var view:IView = viewContainer.getChildAt(idx) as IView;
          if (view != null) {
            processView(view);
          }
        }
      }

      (App.containerMgr as ContainerManagerBase).loader.addEventListener(LoaderEvent.VIEW_LOADED, onViewLoaded, false, 0, true);
    }

    override protected function onDispose():void {
      (App.containerMgr as ContainerManagerBase).loader.removeEventListener(LoaderEvent.VIEW_LOADED, onViewLoaded);
      for each (var widget:DraggableWidget in activeWidgets) {
        widget.dispose();
      }
      super.onDispose();
    }

    private function onViewLoaded(event:LoaderEvent):void {
      processView(event.view as IView);
    }

    private function processView(view:IView):void {
      if (view == null)
        return;

      if (view.as_config.alias == Aliases.LOBBY_HANGAR) {
        hangarView = view as Hangar;
        _log("Hangar view found", "INFO");

        for each (var widget:DraggableWidget in activeWidgets) {
          hangarView.addChild(widget);
        }
      }
    }

    private function _log(msg:String, level:String = "INFO"):void {
      if (this.py_log != null) {
        this.py_log(msg, level);
      }
      else {
        DebugUtils.LOG_WARNING("[MainView][" + level + "]" + msg);
      }
    }

    public function as_createWidget(uuid:int, url:String, width:int, height:int):void {
      _log("as_createWidget [" + uuid + "]: " + url + " " + width + "x" + height, "INFO");

      var widget:DraggableWidget = new DraggableWidget(uuid, width, height);
      widget.addEventListener(DraggableWidget.REQUEST_RESIZE, onWidgetRequestResize);
      widget.addEventListener(DraggableWidget.REQUEST_RELOAD, onWidgetRequestReload);
      widget.addEventListener(DraggableWidget.REQUEST_CLOSE, onWidgetRequestClose);

      activeWidgets.push(widget);
      activeWidgetsByUUID[uuid] = widget;
      hangarView.addChild(widget);
    }

    public function as_setInterfaceScale(scale:Number):void {
      for each (var widget:DraggableWidget in activeWidgets) {
        widget.onInterfaceScaleChanged(scale);
      }
    }

    public function as_onFrame(uuid:int, width:int, height:int, data:Array, shift:int):void {
      var bytes:ByteArray = Utils.decodeIntArrayAMF(data, shift);

      var widget:DraggableWidget = activeWidgetsByUUID[uuid];
      if (widget == null)
        return;

      widget.setFrame(width, height, bytes);
    }

    public function as_setResizeMode(uuid:int, full:Boolean):void {
      var widget:DraggableWidget = activeWidgetsByUUID[uuid];
      if (widget == null)
        return;
      widget.setResizeMode(full);
    }

    private function onWidgetRequestResize(event:ResizeEvent):void {
      if (this.py_requestResize != null) {
        var widget:DraggableWidget = event.target as DraggableWidget;
        this.py_requestResize(widget.uuid, event.scaleX, event.scaleY);
      }
    }

    private function onWidgetRequestReload(event:Event):void {
      if (this.py_requestReload != null) {
        var widget:DraggableWidget = event.target as DraggableWidget;
        this.py_requestReload(widget.uuid);
      }
    }

    private function onWidgetRequestClose(event:Event):void {

      var widget:DraggableWidget = event.target as DraggableWidget;

      var idx:int = activeWidgets.indexOf(widget);
      if (idx >= 0) {
        activeWidgets.splice(idx, 1);
      }

      activeWidgetsByUUID[widget.uuid] = null;

      hangarView.removeChild(widget);
      widget.dispose();
      widget.removeEventListener(DraggableWidget.REQUEST_RESIZE, onWidgetRequestResize);
      widget.removeEventListener(DraggableWidget.REQUEST_RELOAD, onWidgetRequestReload);
      widget.removeEventListener(DraggableWidget.REQUEST_CLOSE, onWidgetRequestClose);

      if (this.py_requestClose != null) {
        this.py_requestClose(widget.uuid);
      }
    }
  }
}