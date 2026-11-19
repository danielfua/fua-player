using System;
using System.Net;
partial class FuaNative {
 async void PlayLibraryEpisode(string id){
  if(!System.Text.RegularExpressions.Regex.IsMatch(id,"^[a-f0-9]{20}$"))return;
  try{using(var client=new WebClient()){client.Headers[HttpRequestHeader.ContentType]="application/json";client.Headers["Origin"]="http://127.0.0.1:8780";await client.UploadStringTaskAsync(new Uri("http://127.0.0.1:8780/api/play"),"POST","{\"id\":\""+id+"\"}");}}
  catch{Send("show-text","Não foi possível abrir o episódio.");}
 }
}
