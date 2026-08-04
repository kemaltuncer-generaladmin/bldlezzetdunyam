<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\User\Models\User;
use Igniter\User\Models\UserRole;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

/**
 * Admin kullanıcısı oluşturur veya günceller.
 *
 * NEDEN AYRI KOMUT VE NEDEN SEEDER DEĞİL: kullanıcı adı ve parola **sırdır**.
 * Seeder'a yazılsalar repoya girerlerdi (AGENTS.md §2.2). Bu komut değerleri
 * argüman/soru olarak alır; hiçbir yere kaydetmez.
 *
 * `igniter:install --no-interaction` admin kullanıcısı oluşturmaz — bu komut
 * o boşluğu doldurur ve her ortamda (staging, prod) tekrar edilebilir kılar.
 *
 * Kullanım:
 *   php artisan veykemtu:admin ad@ornek.com --name="Ad Soyad" --username=ad
 *   (parola sorulur, ekranda görünmez)
 *
 * Parolayı komut satırında vermeyin: kabuk geçmişine ve `ps` çıktısına düşer.
 */
class AdminUserCommand extends Command
{
    protected $signature = 'veykemtu:admin
        {email : Giriş e-postası}
        {--name= : Görünen ad (varsayılan: e-postanın kullanıcı kısmı)}
        {--username= : Kullanıcı adı (varsayılan: e-postanın kullanıcı kısmı)}
        {--role=yonetici : Rol kodu}
        {--super : Süper kullanıcı yap (tüm izinleri atlar)}';

    protected $description = 'Admin kullanıcısı oluşturur veya parolasını günceller.';

    public function handle(): int
    {
        $email = (string) $this->argument('email');
        $local = Str::before($email, '@');

        $password = $this->secret('Parola');
        if ($password === null || strlen($password) < 8) {
            $this->components->error('Parola en az 8 karakter olmalı.');

            return self::FAILURE;
        }

        if ($password !== $this->secret('Parola (tekrar)')) {
            $this->components->error('Parolalar eşleşmedi.');

            return self::FAILURE;
        }

        $role = UserRole::where('code', (string) $this->option('role'))->first();
        if ($role === null && !$this->option('super')) {
            $this->components->error(
                'Rol bulunamadı. Önce `php artisan veykemtu:setup` çalıştırın.',
            );

            return self::FAILURE;
        }

        $user = User::firstOrNew(['email' => $email]);
        $isNew = !$user->exists;

        $user->fill([
            'name' => (string) ($this->option('name') ?: $local),
            'username' => (string) ($this->option('username') ?: $local),
            'email' => $email,
            'status' => true,
            'sale_permission' => 1,
            'super_user' => (bool) $this->option('super'),
        ]);
        // 'password' modelde 'hashed' cast'lidir; düz metin verilir, model hashler.
        $user->password = $password;
        $user->user_role_id = $role?->user_role_id;
        $user->is_activated = true;
        $user->activated_at = now();
        $user->save();

        $this->components->info(
            $isNew ? "Admin kullanıcısı oluşturuldu: {$email}" : "Parola güncellendi: {$email}",
        );
        $this->components->twoColumnDetail(
            '  rol',
            $this->option('super') ? 'süper kullanıcı' : ($role?->name ?? '-'),
        );
        $this->components->twoColumnDetail('  giriş', url('/admin'));

        return self::SUCCESS;
    }
}
