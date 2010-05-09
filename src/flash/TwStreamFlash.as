package {
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
      ExternalInterface.addCallback("ConnectToStream", function(host:String, path:String, username:String, pass:String):void {
        amountRead = 0;
        streamBuffer = "";
        var request:URLRequest = createStreamRequest(host, path, username, pass);
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

    private function createStreamRequest(host:String, path:String, username:String, pass:String):URLRequest {
      var request:URLRequest = new URLRequest("http://10.195.80.143" + path);
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
    private var isReading:Boolean = false;
    private var streamBuffer:String = "";
    private var curlyBraceCount:int = 0;
    private function dataReceived(pe:ProgressEvent):void {
      var toRead:Number = pe.bytesLoaded - amountRead;
      var buffer:String = stream.readUTFBytes(toRead);
      amountRead = pe.bytesLoaded;

      // attempt to restart the stream
      if (!isReading) {
        buffer = buffer.split(/\n/).slice(1).join("\n");
        isReading = true;
      }

      // a stupid state machine to count curly braces
      if ((toRead > 0) && (amountRead > 0)) {
        streamBuffer += buffer;
        var parts:Array = streamBuffer.split(/\n/);
        var lastElement:String = parts.pop();
        parts.forEach(function(s:String, i:int, a:Array):void {
          var encodedString:String =
            s.split("%").join("%25").
              split("\\").join("%5c").
              split("\"").join("%22").
              split("&").join("%26");
          ExternalInterface.call("streamEvent", encodedString);
        });
        streamBuffer = lastElement;
      }
    }

    // call out to javascript that there was an error in the stream
    private function errorReceived(io:IOErrorEvent):void {
      ExternalInterface.call("streamError");
    }
  }
}

