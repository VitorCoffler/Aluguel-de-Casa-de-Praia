# API · Casa da Praia

Base local: `http://localhost:4000`. Corpo JSON, respostas JSON. Erros retornam `{"error":"mensagem"}`. Envie `Authorization: Bearer TOKEN` nas rotas autenticadas. A sessão vale por sete dias e é revogada pelo logout e pela redefinição de senha.

| Método | Rota | Acesso / finalidade |
| --- | --- | --- |
| GET | `/health` | Saúde da API |
| POST | `/auth/register` | Cadastro: `name`, `email`, `password` |
| POST | `/auth/login` | Login: `email`, `password` |
| GET | `/auth/me` | Usuário autenticado |
| POST | `/auth/logout` | Revogar token atual |
| POST | `/auth/forgot` | Solicitar código: `email` |
| POST | `/auth/reset` | Nova senha: `token`, `password` |
| GET | `/houses?q=&guests=1&max_price=50000` | Catálogo; preço máximo em centavos |
| GET | `/houses/:id` | Detalhes de anúncio ativo; pausado só para dono |
| GET | `/houses/:id/availability` | Intervalos ocupados, sem dados de hóspedes |
| GET | `/host/houses` | Anúncios do próprio usuário |
| POST | `/uploads` | Upload autenticado: `base64`; retorna `url` |
| GET | `/uploads/:arquivo` | Foto pública usada nos anúncios |
| POST | `/host/houses` | Criar anúncio |
| PUT | `/host/houses/:id` | Editar anúncio próprio |
| GET | `/host/houses/:id/blocks` | Bloqueios manuais; somente dono |
| POST | `/host/houses/:id/blocks` | Bloquear: `start_date`, `end_date` |
| DELETE | `/host/blocks/:id` | Liberar bloqueio próprio |
| POST | `/bookings` | Confirmar reserva |
| GET | `/bookings` | Reservas do hóspede autenticado |
| GET | `/host/bookings` | Reservas das casas do anfitrião |
| POST | `/bookings/:id/cancel` | Cancelar: dono ou hóspede da reserva |

## Exemplo de anúncio

```json
{
  "name": "Casa Brisa do Mar",
  "city": "Guarapari - ES",
  "description": "Casa com dois quartos, varanda e churrasqueira perto da praia.",
  "price_cents": 25000,
  "guests": 4,
  "bedrooms": 2,
  "amenities": ["Wi-Fi", "Churrasqueira"],
  "photos": ["/uploads/URL_RETORNADA_PELO_UPLOAD.jpg"],
  "active": true
}
```

Use a URL real devolvida por `/uploads`. A API só aceita imagens enviadas pela própria conta, de até 3 MB, com assinatura de JPG/PNG/WebP. SVG e arquivos executáveis não são aceitos. O servidor limita o corpo HTTP e gera nomes aleatórios, sem usar o nome enviado pelo usuário.

## Exemplo de reserva

```json
{
  "house_id": 1,
  "start_date": "2027-01-10",
  "end_date": "2027-01-13",
  "guests": 2,
  "expected_price_cents": 25000
}
```

O servidor retorna `409` se houver conflito de datas ou mudança de preço. O total é calculado pelo servidor e não é aceito como autoridade no corpo enviado pelo cliente.

## Modelo de dados

- `users`: cadastro e hash de senha com scrypt + salt aleatório.
- `sessions`: hash do token aleatório, usuário e validade.
- `houses`: proprietário, descrição, diária, capacidade, quartos, comodidades e publicação.
- `photos`: URLs e ordem das fotos de cada casa.
- `uploads`: dono de cada arquivo enviado.
- `bookings`: hóspede, casa, intervalo, diária contratada, total e estado.
- `blocks`: períodos manuais de indisponibilidade.
- `resets`: hash do código de recuperação, usuário e validade.

As comodidades são uma lista JSON na tabela de casas. São usadas consultas parametrizadas. Transações `BEGIN IMMEDIATE` e gatilhos garantem exclusão de intervalos concorrentes. Não há endpoint público para editar valores ou status de reservas livremente.
