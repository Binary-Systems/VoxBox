/*! VoxBox / Binary Systems — dynamic copyright year (same idea as www.binary-systems.com/js/copyright.js) */
(function () {
  var y = new Date().getFullYear();
  var spans = document.querySelectorAll(".bsi-year, #bsi-year");
  for (var i = 0; i < spans.length; i++) {
    spans[i].textContent = String(y);
  }
  var footer = document.getElementById("footer");
  var script = document.currentScript;
  // Rewriting #footer while this script sits inside it reloads the script.
  // The public site keeps copyright.js outside the footer. Span updates above
  // cover the FreePBX footer, where the script tag is inside #footer.
  if (footer && script && !footer.contains(script)) {
    footer.innerHTML = footer.innerHTML.replace(/2007-\d{4}/g, "2007-" + y);
  }
})();
