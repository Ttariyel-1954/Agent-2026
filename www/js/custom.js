// =============================================
// ARTI-2026: Xüsusi JavaScript
// =============================================

$(document).ready(function() {

  // =============================================
  // 1. Shiny ilə Əlaqə (Custom Message Handlers)
  // =============================================

  // Uğurlu bildiriş
  Shiny.addCustomMessageHandler('notify_success', function(message) {
    showNotification(message, 'success');
  });

  // Xəta bildirişi
  Shiny.addCustomMessageHandler('notify_error', function(message) {
    showNotification(message, 'error');
  });

  // Xəbərdarlıq bildirişi
  Shiny.addCustomMessageHandler('notify_warning', function(message) {
    showNotification(message, 'warning');
  });

  // Yükləmə göstəricisi
  Shiny.addCustomMessageHandler('show_loading', function(message) {
    $('#loading-overlay').fadeIn(200);
  });

  Shiny.addCustomMessageHandler('hide_loading', function(message) {
    $('#loading-overlay').fadeOut(200);
  });

  // =============================================
  // 2. Bildiriş Sistemi
  // =============================================

  function showNotification(message, type) {
    var colors = {
      success: '#27ae60',
      error: '#e74c3c',
      warning: '#f39c12',
      info: '#3498db'
    };

    var icons = {
      success: 'fa-check-circle',
      error: 'fa-times-circle',
      warning: 'fa-exclamation-triangle',
      info: 'fa-info-circle'
    };

    var $notification = $('<div class="arti-notification">')
      .css({
        position: 'fixed',
        top: '20px',
        right: '20px',
        backgroundColor: colors[type] || colors.info,
        color: '#fff',
        padding: '15px 25px',
        borderRadius: '8px',
        boxShadow: '0 4px 20px rgba(0,0,0,0.2)',
        zIndex: 9999,
        display: 'none',
        maxWidth: '400px',
        fontSize: '14px'
      })
      .html('<i class="fa ' + (icons[type] || icons.info) + '"></i> ' + message);

    $('body').append($notification);
    $notification.fadeIn(300);

    setTimeout(function() {
      $notification.fadeOut(300, function() {
        $(this).remove();
      });
    }, 4000);
  }

  // =============================================
  // 3. Sidebar Effektləri
  // =============================================

  // Aktiv menyunun vurğulanması
  $('.sidebar-menu li a').on('click', function() {
    $('.sidebar-menu li').removeClass('active');
    $(this).parent().addClass('active');
  });

  // Menyu elementlərinin animasiyası
  $('.sidebar-menu > li').each(function(index) {
    $(this).css({
      'animation-delay': (index * 0.05) + 's',
      'animation': 'fadeIn 0.3s ease-out forwards'
    });
  });

  // =============================================
  // 4. Cədvəl Təkmilləşdirmələri
  // =============================================

  // DataTable sütun genişliyi avtomatik tənzimlənməsi
  $(document).on('shown.bs.tab', function() {
    $.fn.dataTable.tables({ visible: true, api: true }).columns.adjust();
  });

  // Cədvəl sıralarında klik effekti
  $(document).on('click', '.dataTable tbody tr', function() {
    var $row = $(this);
    $row.siblings('.selected').removeClass('selected');
    $row.toggleClass('selected');
  });

  // =============================================
  // 5. Form Validasiyası
  // =============================================

  // FIN validasiyası (7 simvol, hərflər və rəqəmlər)
  $(document).on('input', 'input[id*="fin"]', function() {
    var val = $(this).val().toUpperCase();
    $(this).val(val.replace(/[^A-Z0-9]/g, '').substring(0, 7));
    if (val.length === 7) {
      $(this).css('border-color', '#27ae60');
    } else {
      $(this).css('border-color', '#dce4ec');
    }
  });

  // Telefon nömrəsi formatı
  $(document).on('input', 'input[id*="phone"]', function() {
    var val = $(this).val().replace(/[^\d+]/g, '');
    if (!val.startsWith('+994') && val.length > 0 && !val.startsWith('+')) {
      val = '+994' + val;
    }
    $(this).val(val.substring(0, 13));
  });

  // E-poçt validasiyası
  $(document).on('blur', 'input[type="email"], input[id*="email"]', function() {
    var email = $(this).val();
    var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (email && !emailRegex.test(email)) {
      $(this).css('border-color', '#e74c3c');
      showNotification('Düzgün e-poçt ünvanı daxil edin', 'warning');
    } else {
      $(this).css('border-color', '#27ae60');
    }
  });

  // =============================================
  // 6. Klaviatura Qısa Yolları
  // =============================================

  $(document).on('keydown', function(e) {
    // Ctrl+S - Saxla (default-u ləğv et)
    if (e.ctrlKey && e.key === 's') {
      e.preventDefault();
      var $saveBtn = $('.btn-success:visible:first');
      if ($saveBtn.length) $saveBtn.trigger('click');
    }

    // Escape - Modalı bağla
    if (e.key === 'Escape') {
      $('.modal.in').modal('hide');
    }

    // Ctrl+F - Axtarış
    if (e.ctrlKey && e.key === 'f') {
      var $searchInput = $('.dataTables_filter input:visible:first');
      if ($searchInput.length) {
        e.preventDefault();
        $searchInput.focus();
      }
    }
  });

  // =============================================
  // 7. Tarix və Vaxt Formatlaması
  // =============================================

  // Azərbaycan tarix formatı
  window.formatDateAZ = function(date) {
    if (!date) return '';
    var d = new Date(date);
    var day = ('0' + d.getDate()).slice(-2);
    var month = ('0' + (d.getMonth() + 1)).slice(-2);
    var year = d.getFullYear();
    return day + '.' + month + '.' + year;
  };

  // Nisbi vaxt (5 dəqiqə əvvəl)
  window.timeAgo = function(date) {
    var seconds = Math.floor((new Date() - new Date(date)) / 1000);
    var intervals = [
      { label: 'il', seconds: 31536000 },
      { label: 'ay', seconds: 2592000 },
      { label: 'həftə', seconds: 604800 },
      { label: 'gün', seconds: 86400 },
      { label: 'saat', seconds: 3600 },
      { label: 'dəqiqə', seconds: 60 }
    ];
    for (var i = 0; i < intervals.length; i++) {
      var count = Math.floor(seconds / intervals[i].seconds);
      if (count >= 1) return count + ' ' + intervals[i].label + ' əvvəl';
    }
    return 'indicə';
  };

  // =============================================
  // 8. Yükləmə Overlay
  // =============================================

  if (!$('#loading-overlay').length) {
    $('body').append(
      '<div id="loading-overlay" style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;' +
      'background:rgba(44,62,80,0.7);z-index:9998;text-align:center;padding-top:40vh;">' +
      '<div style="color:#fff;font-size:18px;">' +
      '<i class="fa fa-spinner fa-spin fa-3x"></i><br><br>Yüklənir...</div></div>'
    );
  }

  // =============================================
  // 9. Çap Funksiyası
  // =============================================

  window.printSection = function(sectionId) {
    var $section = $('#' + sectionId);
    if (!$section.length) return;
    var printWindow = window.open('', '_blank');
    printWindow.document.write(
      '<html><head><title>ARTI-2026 Çap</title>' +
      '<link rel="stylesheet" href="css/custom.css">' +
      '<style>body{padding:20px;font-family:Arial,sans-serif;}</style>' +
      '</head><body>' + $section.html() + '</body></html>'
    );
    printWindow.document.close();
    printWindow.print();
  };

  // =============================================
  // 10. Performans Optimallaşdırması
  // =============================================

  // Debounce funksiyası
  window.debounce = function(func, wait) {
    var timeout;
    return function() {
      var context = this, args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(function() {
        func.apply(context, args);
      }, wait);
    };
  };

  // Pəncərə ölçüsü dəyişdikdə qrafikləri yenilə
  $(window).on('resize', debounce(function() {
    $('.plotly').each(function() {
      Plotly.Plots.resize(this);
    });
  }, 250));

  console.log('ARTI-2026 JavaScript yükləndi.');
});
