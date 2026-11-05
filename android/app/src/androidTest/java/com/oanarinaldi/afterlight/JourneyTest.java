package com.oanarinaldi.afterlight;
import android.graphics.Bitmap;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.ViewGroup;
import android.webkit.WebView;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.json.*;
import java.io.*;
import java.util.concurrent.*;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class) public class JourneyTest {
 private MainActivity activity;private WebView web;
 private Object eval(String script) throws Exception {
  CountDownLatch latch=new CountDownLatch(1);String[] result={"null"};
  activity.runOnUiThread(()->web.evaluateJavascript(script,v->{result[0]=v;latch.countDown();}));
  assertTrue("JavaScript callback timed out",latch.await(25,TimeUnit.SECONDS));return new JSONTokener(result[0]).nextValue();
 }
 private void waitFor(String expression,long timeout) throws Exception {
  long end=SystemClock.elapsedRealtime()+timeout;
  while(SystemClock.elapsedRealtime()<end){if(Boolean.TRUE.equals(eval(expression)))return;SystemClock.sleep(200);}
  fail("Timed out: "+expression+"; state="+eval("window.afterlightState&&JSON.stringify(window.afterlightState())")+"; error="+eval("document.querySelector('.error')?.textContent"));
 }
 private void click(String selector) throws Exception {assertEquals(Boolean.TRUE,eval("(()=>{const e=document.querySelector("+JSONObject.quote(selector)+");if(!e||e.disabled)return false;e.click();return true;})()"));}
 private void capture(String name) throws Exception {
  int frames=((Number)eval("window.afterlightState().frames")).intValue();
  waitFor("window.afterlightState().frames>="+(frames+3)+" && document.querySelector('#loading').hidden",120000);
  assertEquals("A scene shader failed to compile",0,((Number)eval("window.afterlightState().shaderErrors")).intValue());
  Bitmap image=InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();
  File folder=new File(activity.getExternalFilesDir(null),"qa");assertTrue(folder.exists()||folder.mkdirs());
  try(FileOutputStream file=new FileOutputStream(new File(folder,name.replace("phone-",InstrumentationRegistry.getArguments().getString("capturePrefix","phone-"))+".png"))){assertTrue(image.compress(Bitmap.CompressFormat.PNG,100,file));}image.recycle();
 }
 private void hold(String selector,long milliseconds) throws Exception {
  JSONObject p=new JSONObject((String)eval("(()=>{const r=document.querySelector("+JSONObject.quote(selector)+").getBoundingClientRect();return JSON.stringify({x:(r.x+r.width/2)*devicePixelRatio,y:(r.y+r.height/2)*devicePixelRatio});})()"));
  long down=SystemClock.uptimeMillis();float x=(float)p.getDouble("x"),y=(float)p.getDouble("y");
  MotionEvent press=MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,x,y,0);InstrumentationRegistry.getInstrumentation().sendPointerSync(press);press.recycle();SystemClock.sleep(milliseconds);
  MotionEvent release=MotionEvent.obtain(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x,y,0);InstrumentationRegistry.getInstrumentation().sendPointerSync(release);release.recycle();
 }
 @Test public void fullGameJourneyAndFourDistricts() throws Exception {
  try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
   scenario.onActivity(a->{activity=a;web=(WebView)((ViewGroup)a.findViewById(android.R.id.content)).getChildAt(0);});
   UiDevice device=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
   UiObject2 got=device.wait(Until.findObject(By.text("Got it")),2000);if(got!=null)got.click();
   waitFor("!!window.afterlightReview && document.querySelector('#loading').hidden",120000);
   eval("window.afterlightReview.reset()");waitFor("window.afterlightState().renderer==='showroom'",120000);
   assertEquals("home",eval("window.afterlightState().screen"));
   assertEquals(Boolean.TRUE,eval("[...document.images].every(i=>i.complete&&i.naturalWidth>0)"));capture("phone-01-home");
   click("[data-tab='2']");waitFor("document.querySelector('.specs')!==null",10000);capture("phone-02-garage");
   click("[data-tab='3']");assertEquals(4,((Number)eval("document.querySelectorAll('.chapter').length")).intValue());capture("phone-03-story");
   click("[data-tab='1']");assertEquals(5,((Number)eval("document.querySelectorAll('.route').length")).intValue());capture("phone-04-world");
   if("true".equals(InstrumentationRegistry.getArguments().getString("menusOnly"))){click("[data-tab='0']");click("[data-action='settings']");waitFor("document.querySelector('.settings-card')!==null",10000);capture("phone-09-settings");return;}
   click("[data-action='race:0:circuit']");waitFor("window.afterlightState().screen==='briefing'",120000);capture("phone-05-briefing");click("[data-action='begin']");
   waitFor("window.afterlightState().elapsed>3",30000);hold("[data-hold='right']",400);hold("[data-hold='nitro']",1000);capture("phone-06-race");
   assertTrue(((Number)eval("window.afterlightState().speed")).doubleValue()>10);
   click("[data-action='pause']");assertEquals("paused",eval("window.afterlightState().screen"));double elapsed=((Number)eval("window.afterlightState().elapsed")).doubleValue();SystemClock.sleep(500);assertEquals(elapsed,((Number)eval("window.afterlightState().elapsed")).doubleValue(),.001);capture("phone-07-pause");click("[data-action='resume']");
   eval("window.afterlightReview.finish()");waitFor("window.afterlightState().screen==='results'",10000);capture("phone-08-results");assertTrue(((Number)eval("window.afterlightState().credits")).intValue()>0);
   click("[data-action='next']");click("[data-tab='0']");click("[data-action='settings']");waitFor("document.querySelector('.settings-card')!==null",10000);capture("phone-09-settings");click("[data-action='close-settings']");
   int earned=((Number)eval("window.afterlightState().credits")).intValue();
   scenario.recreate();scenario.onActivity(a->{activity=a;web=(WebView)((ViewGroup)a.findViewById(android.R.id.content)).getChildAt(0);});waitFor("!!window.afterlightReview && document.querySelector('#loading').hidden",120000);
   assertEquals(earned,((Number)eval("window.afterlightState().credits")).intValue());assertEquals(1,((Number)eval("window.afterlightState().races")).intValue());
   eval("window.afterlightReview.fixtures()");
   for(int region=1;region<4;region++){
    eval("window.afterlightReview.race("+region+",'sprint')");waitFor("window.afterlightState().screen==='briefing'||window.afterlightState().screen==='race'",120000);
    if("briefing".equals(eval("window.afterlightState().screen")))click("[data-action='begin']");
    waitFor("window.afterlightState().elapsed>1",30000);capture("phone-district-"+region);click("[data-action='pause']");click("[data-action='leave']");
   }
   int savedCredits=((Number)eval("window.afterlightState().credits")).intValue(),savedRaces=((Number)eval("window.afterlightState().races")).intValue();
   scenario.recreate();scenario.onActivity(a->{activity=a;web=(WebView)((ViewGroup)a.findViewById(android.R.id.content)).getChildAt(0);});waitFor("!!window.afterlightReview && document.querySelector('#loading').hidden",120000);assertEquals(savedCredits,((Number)eval("window.afterlightState().credits")).intValue());assertEquals(savedRaces,((Number)eval("window.afterlightState().races")).intValue());
  }
 }
}
