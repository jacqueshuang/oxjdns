'use strict';
'require fs';
'require ui';
'require view';

return view.extend({
	helper: '/usr/libexec/oxidns-openwrt',

	callHelper: function(action) {
		return fs.exec(this.helper, [ action ]).then(function(res) {
			var output = (res.stdout || '').trim();

			if (!output)
				return {};

			try {
				return JSON.parse(output);
			}
			catch (e) {
				return { password: output };
			}
		});
	},

	load: function() {
		return L.resolveDefault(this.callHelper('status'), {
			running: false,
			enabled: false,
			username: 'admin',
			password: ''
		});
	},

	webuiUrl: function() {
		var host = window.location.hostname || 'openwrt.lan';

		if (host.indexOf(':') > -1 && host.charAt(0) != '[')
			host = '[' + host + ']';

		return 'http://' + host + ':9199/';
	},

	handleAction: function(action) {
		return this.callHelper(action)
			.then(function() {
				window.location.reload();
			})
			.catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
	},

	handleResetPassword: function() {
		return this.callHelper('reset-password')
			.then(L.bind(function(status) {
				ui.showModal(_('OxiDNS Password Reset'), [
					E('p', {}, _('The new OxiDNS WebUI/API password is:')),
					E('pre', {}, [ status.password || '' ]),
					E('div', { 'class': 'right' }, [
						E('button', {
							'class': 'btn',
							'click': function() {
								ui.hideModal();
								window.location.reload();
							}
						}, _('Close'))
					])
				]);
			}, this))
			.catch(function(e) {
				ui.addNotification(null, E('p', e.message));
			});
	},

	renderStatus: function(status) {
		var webui = this.webuiUrl();
		var running = status.running ? _('Running') : _('Stopped');
		var enabled = status.enabled ? _('Enabled') : _('Disabled');

		return E('div', { 'class': 'cbi-section' }, [
			E('div', { 'class': 'cbi-section-descr' }, [
				_('OxiDNS listens on DNS port 5335 by default to avoid conflicting with dnsmasq. The bundled WebUI is available on port 9199.')
			]),
			E('div', { 'class': 'table cbi-section-table' }, [
				E('div', { 'class': 'tr cbi-section-table-row' }, [
					E('div', { 'class': 'td left', 'style': 'width: 25%' }, _('Service status')),
					E('div', { 'class': 'td left' }, running)
				]),
				E('div', { 'class': 'tr cbi-section-table-row' }, [
					E('div', { 'class': 'td left' }, _('Autostart')),
					E('div', { 'class': 'td left' }, enabled)
				]),
				E('div', { 'class': 'tr cbi-section-table-row' }, [
					E('div', { 'class': 'td left' }, _('WebUI URL')),
					E('div', { 'class': 'td left' }, [
						E('a', { 'href': webui, 'target': '_blank', 'rel': 'noreferrer' }, webui)
					])
				]),
				E('div', { 'class': 'tr cbi-section-table-row' }, [
					E('div', { 'class': 'td left' }, _('Username')),
					E('div', { 'class': 'td left' }, status.username || 'admin')
				]),
				E('div', { 'class': 'tr cbi-section-table-row' }, [
					E('div', { 'class': 'td left' }, _('Password')),
					E('div', { 'class': 'td left' }, [
						E('code', {}, status.password || _('Not generated yet'))
					])
				])
			]),
			E('div', { 'class': 'cbi-page-actions' }, [
				E('button', {
					'class': 'btn cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(this, 'handleAction', 'start')
				}, _('Start')),
				' ',
				E('button', {
					'class': 'btn cbi-button cbi-button-reset',
					'click': ui.createHandlerFn(this, 'handleAction', 'stop')
				}, _('Stop')),
				' ',
				E('button', {
					'class': 'btn cbi-button cbi-button-reload',
					'click': ui.createHandlerFn(this, 'handleAction', 'restart')
				}, _('Restart')),
				' ',
				E('button', {
					'class': 'btn cbi-button',
					'click': ui.createHandlerFn(this, 'handleResetPassword')
				}, _('Reset Password')),
				' ',
				E('a', {
					'class': 'btn cbi-button cbi-button-action',
					'href': webui,
					'target': '_blank',
					'rel': 'noreferrer'
				}, _('Open WebUI'))
			])
		]);
	},

	render: function(status) {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('OxiDNS')),
			this.renderStatus(status || {})
		]);
	}
});
