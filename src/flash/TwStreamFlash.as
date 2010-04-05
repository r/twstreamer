package {
  import com.adobe.serialization.json.JSON;
  import com.adobe.serialization.json.JSONParseError;
  import flash.display.Sprite;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.external.ExternalInterface;
  import flash.net.URLRequest;
  import flash.net.URLRequestHeader;
  import flash.net.URLRequestMethod;
  import flash.net.URLStream;
  import mx.utils.Base64Encoder;

  public class TwStreamFlash extends Sprite {
    private var stream:URLStream; // the connection to the streaming API

    public function TwStreamFlash() {
      ExternalInterface.addCallback("ConnectToStream", function(path:String, username:String, pass:String):void {
        amountRead = 0;
        var request:URLRequest = createStreamRequest(path, username, pass);
        stream = new URLStream();
        stream.addEventListener(IOErrorEvent.IO_ERROR, errorReceived);
        stream.addEventListener(ProgressEvent.PROGRESS, dataReceived);
        stream.load(request);
      });

      ExternalInterface.addCallback("DisconnectFromStream", function():void {
        stream.close();
        stream = null;
      });
    }

    private function createStreamRequest(path:String, username:String, pass:String):URLRequest {
      var request:URLRequest = new URLRequest("http://betastream.twitter.com" + path);
      request.requestHeaders = new Array(new URLRequestHeader("Authorization", "Basic " + b64encode(username + ":" + pass)));
      request.method = URLRequestMethod.POST;
      request.data = 0;
      return request;
    }

    // a simple helper that will base-64 encode a string
    private function b64encode(s:String):String {
      var encoder:Base64Encoder = new Base64Encoder();
      encoder.encode(s);
      return encoder.toString();
    }

    // parse the incoming data stream -- this will call out to "streamEvent"
    // in javascript with the JSON
    private var amountRead:int = 0;
    private function dataReceived(pe:ProgressEvent):void {
      var toRead:Number = pe.bytesLoaded - amountRead;
      var buffer:String = stream.readUTFBytes(toRead);
      amountRead = pe.bytesLoaded;

      var emptyMatcher:RegExp = /^\s*$/;
      buffer.split("\n").
        filter(function(e:String, index:int, array:Array):Boolean {
          // filter out keep alive newlines and null objects
          return (e.search(emptyMatcher) == -1);
        }).
        forEach(function(e:String, index:int, array:Array):void {
          // send this off to javascript
          ExternalInterface.call("streamEvent", e);
        });
    }

    // call out to javascript that there was an error in the stream
    private function errorReceived(io:IOErrorEvent):void {
      ExternalInterface.call("streamError");
    }
  }
}

