pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

-- TODO:
-- 3. more AIs
-- 4. start screen
-- 8. animations (drawing and playing)
-- 5. scoring + rounds

-- bugs:
-- NONE we're too GOOD for bugs


CARD_CONSTS = {}
CARD_CONSTS.width = 16
CARD_CONSTS.height = 24

-- colors: red 0, green 1, blue 2, yellow 3, wild 4
CARD_COLORS = {
  [0] = 8, -- red
  [1] = 11, -- green
  [2] = 12, -- blue
  [3] = 10, -- yellow
  [4] = 7 -- white
}

INACTIVE_PLAYER_COLOR = 5

SPECIAL_RANKS = {
  [10] = 'R',
  [11] = 'S',
  [12] = 'D',
  [13] = 'W',
  [14] = 'F'
}

DISCARD_COORDS = {
  left = 64 - CARD_CONSTS.width - 2,
  top = 64 - CARD_CONSTS.height / 2
}

deck = {}
players = {}
discard = {}
sprite_render_list = {}
ai_call_timers = {}
current_player = 1
cursor = 1
leftmost = 1
turn_order = 1
is_on_deck = false
is_wild_selection_mode = false
is_uno_called = false
vulnerable_player = 0
wild_cursor = 1
is_game_over_mode = false
is_play_or_keep_mode = false
play_or_keep_card = nil
play_or_keep_cursor = 1
debug_string = ''

wait = 0

function _init()
  cls()

  deck = {}
  deck = generate_deck()
  deck = shuffle(deck)

  players = {
    { name = 'you', hand = {}, ai = nil, color = nil},
    { name = 'jOEY', hand = {}, ai = joey, color = 9, max_reaction_time = 2},
    { name = 'mAI', hand = {}, ai = mai, color = 4, max_reaction_time = 1},
    { name = 'sOLOMON', hand = {}, ai = solomon, color = 14, max_reaction_time = 2}
  }

  for i = 1, #players do
    players[i].hand = draw_first_hand()
  end

  current_player = 1
  cursor = 1
  leftmost = 1
  is_on_deck = false
  is_wild_selection_mode = false
  wild_cursor = 1
  is_uno_called = false
  sprite_render_list = {}
  vulnerable_player = 0
  ai_call_timers = {}
  is_game_over_mode = false
  is_play_or_keep_mode = false
  play_or_keep_card = nil
  play_or_keep_cursor = 1

  print_deck()
  render_hand()

  discard = {}
  add(discard, draw())
  render_discard()
end

function _update()

  if is_game_over_mode then
    handle_game_over_mode_input()
    return
  end

  clean_sprite_render_list()
  handle_ai_call_timers()

  if current_player == 1 then
    if is_wild_selection_mode then
      handle_wild_selection_mode_input()
    elseif is_on_deck then
      handle_deck_input()
    elseif is_play_or_keep_mode then
      handle_play_or_keep_mode_input()
    else
      handle_input()
    end
  else
    if wait >= 30 then
      players[current_player]['ai'](current_player)
      wait = 0
    else
      if btnp(5) then
        if vulnerable_player > 1 then
          add(players[vulnerable_player].hand, draw())
          add(players[vulnerable_player].hand, draw())
          add_offensive_uno(1)
          vulnerable_player = 0
        else
          vulnerable_player = 0
        end
      end
      wait += 1
    end
  end
end

function _draw()
  cls()

  if is_game_over_mode then
    render_game_over_screen()
    return
  end

  render_hand()
  render_scroll_arrows()
  render_discard()
  render_deck()
  render_ai()

  if is_wild_selection_mode then
    render_wild_selection()
  elseif is_on_deck then
    render_deck_cursor()
  elseif is_play_or_keep_mode then
    render_play_or_keep_card()
    render_play_or_keep_cursor()
  elseif current_player == 1 then
    render_cursor()
  end

  render_sprites()

  -- render_debug()
end

function get_display_rank(rank)
  if rank < 10 then
    return rank -- @todo: will we run into an issue with string conversion?
  else
    return SPECIAL_RANKS[rank]
  end
end

function render_card(card, x, y, is_active)
  local color = 5 -- gray/inactive
  if is_active == nil then is_active = true end
  if is_active then color = CARD_COLORS[card.color] end

  rectfill(x, y, x + CARD_CONSTS.width, y + CARD_CONSTS.height, color)
  print(get_display_rank(card.rank), x + 1, y + 1, 0) -- black
  print(get_display_rank(card.rank), x + CARD_CONSTS.width - 3, y + CARD_CONSTS.height - 5, 0)
end

function render_hand()
  local visible_cards = subseq(players[1].hand, leftmost, leftmost + 6)
  for index, card in pairs(visible_cards) do
    local x = (index - 1) * (CARD_CONSTS.width + 2)
    local y = 96 + 4 -- a little more than 3/4s down the screen
    if index == cursor and not is_on_deck and current_player == 1 then
      y -= 1
    end
    render_card(card, x, y, current_player == 1)
  end
end

function render_cursor()
  local card_width = CARD_CONSTS.width + 2 -- 1-pixel border on each side. should this be in the constant?
  local x = ((cursor - 1) * card_width + (card_width / 2)) - 4
  local y = 96 - 4
  spr(2, x, y)
end

function render_scroll_arrows()
  if leftmost > 1 then
    spr(1, -3, 96 - 5, 1, 1, true) -- left arrow
  end

  if leftmost < #players[1].hand - 6 then
    spr(1, 128 - 8, 96 - 5, 1, 1, false) -- right arrow
  end
end

function render_discard()
  render_card(
    discard[#discard],
    DISCARD_COORDS.left,
    DISCARD_COORDS.top
  )
end

function render_debug()
  print(debug_string, 128 - 64, 4, 14)
end

function render_wild_boxes()
  local w = 3
  local h = 3
  local x = DISCARD_COORDS.left - 2 - w  -- to the left of the discard
  local y = DISCARD_COORDS.top -- starting at the top of the card
  local bm = 2

  for i = 1, 4 do
    local box_x = x
    if i == wild_cursor then box_x -= 1 end
    local box_y = y + ((i - 1) * (h + bm))
    rectfill(box_x, box_y, box_x + w, box_y + h, CARD_COLORS[i - 1])
  end
end

function render_wild_selection()
  local x = DISCARD_COORDS.left - 2 - 3 - 2 - 1 - 7  -- to the left of the discard, and the wild boxes
  local y = DISCARD_COORDS.top -- starting at the top of the card
  spr(3, x, y + ((wild_cursor - 1) * (3 + 2)) + 1, 1, 1, true) -- 3 + 2 from wild box height and bottom margin
  render_wild_boxes()
end

function render_ai()
  local y_offset = 6
  if #players == 2 then
    local y = 2
    local name_coords = get_center_text_positions(players[2].name, 64)
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), 64)
    local color = get_player_display_color(2)

    print(players[2].name, name_coords.x, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)
  end

  if #players == 3 then
    local y = 32
    local name_center = -get_center_text_positions(players[2].name).x
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), name_center)
    local color = get_player_display_color(2)

    print(players[2].name, 0, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)

    name_center = get_center_text_positions(players[3].name, 128 - 4).x
    card_count_coords = get_center_text_positions(tostr(#players[3].hand), name_center)
    color = get_player_display_color(3)

    print(players[3].name, (128 - #players[3].name * 4 - 2), y, color)
    print(#players[3].hand, card_count_coords.x, y + y_offset, color)
  end

  if #players == 4 then
    local y = 32
    local name_center = -get_center_text_positions(players[2].name).x
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), name_center)
    local color = get_player_display_color(2)

    print(players[2].name, 0, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)

    y = 2
    local name_coords = get_center_text_positions(players[3].name, 64)
    card_count_coords = get_center_text_positions(tostr(#players[3].hand), 64)
    color = get_player_display_color(3)

    print(players[3].name, name_coords.x, y, color)
    print(#players[3].hand, card_count_coords.x, y + y_offset, color)

    y = 32
    name_center = get_center_text_positions(players[4].name, 128 - 4).x
    card_count_coords = get_center_text_positions(tostr(#players[4].hand), name_center)
    color = get_player_display_color(4)

    print(players[4].name, (128 - #players[4].name * 4 - 2), y, color)
    print(#players[4].hand, card_count_coords.x, y + y_offset, color)
  end
end

function render_deck_cursor()
  local x = DISCARD_COORDS.left + CARD_CONSTS.width / 2 + CARD_CONSTS.width
  local y = DISCARD_COORDS.top - 2 - 5
  spr(2, x, y)
end

function render_deck()
  if #deck == 0 then return end

  local x = DISCARD_COORDS.left + 3 + CARD_CONSTS.width -- to the right of the discard
  local y = DISCARD_COORDS.top
  local coords = get_center_text_positions(tostr(#deck), x, y)
  rect(x, y, x + CARD_CONSTS.width, y + CARD_CONSTS.height, 7) -- white
  print(#deck, coords.x + CARD_CONSTS.width / 2, coords.y + CARD_CONSTS.height / 2, 7) -- white
end

function render_game_over_screen()
  local winner_text = ''

  if current_player == 1 then
    winner_text = 'yOU WIN!'
  else
    winner_text = players[current_player].name .. ' WINS!'
  end

  local coords = get_center_text_positions(winner_text, 64, 64)
  print(winner_text, coords.x, coords.y, 7)
end

function render_play_or_keep_card()

  if play_or_keep_card == nil then return end

  local x = 64 - (CARD_CONSTS.width / 2)
  local y = DISCARD_COORDS.top + CARD_CONSTS.height + 2

  render_card(play_or_keep_card, x, y)
end

function render_play_or_keep_cursor()

  if play_or_keep_card == nil then return end

  local play_or_keep_x = 64 + (CARD_CONSTS.width / 2) + 2
  local play_x = play_or_keep_x
  local play_y = DISCARD_COORDS.top + CARD_CONSTS.height + 2
  local keep_x = play_or_keep_x
  local keep_y = DISCARD_COORDS.top + CARD_CONSTS.height + 2 + 6
  local cursor_x = play_or_keep_x + 4 * 4 + 1
  local cursor_y = 0

  if play_or_keep_cursor == 1 then
    play_x += 1
    cursor_y = play_y + 1
  else
    keep_x += 1
    cursor_y = keep_y + 1
  end

  print('play', play_x, play_y, 7) -- white
  print('keep', keep_x, keep_y, 7) -- white
  spr(3, cursor_x, cursor_y)
end

function add_defensive_uno(player)
  local x = 0
  local y = 0
  local flip_x = false
  local duration = 1

  if player == 1 then
    x = 64 + (CARD_CONSTS.width / 2) + 2
    y = 96 - 8 + 2
  elseif #players == 2 then
    if player == 2 then
      x = 64 + #players[player].name * 2 + 2
      y = 2
    end
  elseif #players == 3 then
    if player == 2 then
      x = #players[player].name * 4 + 2
      y = 32
    elseif player == 3 then
      x = 128 - #players[player].name * 4 - 16 - 4
      y = 32
      flip_x = true
    end
  elseif #players == 4 then
    if player == 2 then
      x = #players[player].name * 4 + 2
      y = 32
    elseif player == 3 then
      x = 64 + #players[player].name * 2 + 2
      y = 2
    elseif player == 4 then
      x = 128 - #players[player].name * 4 - 16 - 4
      y = 32
      flip_x = true
    end
  end

  add_sprite_to_render_list(4, x, y, duration, 2, 1, flip_x)
  add_sprite_to_render_list(6, x, y, duration, 2, 1)
end

function add_offensive_uno(player)
  local x = 0
  local y = 0
  local duration = 1

  if player == 1 then
    x = 64 + (CARD_CONSTS.width / 2) + 2
    y = 96 - 3 * 8
  elseif #players == 2 then
    if player == 2 then
      x = 64 + #players[player].name * 2 + 2
      y = 2
    end
  elseif #players == 3 then
    if player == 2 then
      x = #players[player].name * 4 + 2
      y = 32
    elseif player == 3 then
      x = 128 - #players[player].name * 4 - 16 - 4
      y = 32
    end
  elseif #players == 4 then
    if player == 2 then
      x = #players[player].name * 4 + 2
      y = 32
    elseif player == 3 then
      x = 64 + #players[player].name * 2 + 2
      y = 2
    elseif player == 4 then
      x = 128 - #players[player].name * 4 - 16 - 4
      y = 32
    end
  end

  add_sprite_to_render_list(16, x, y, duration, 3, 3)
end

function render_sprites()
  for sprite in all(sprite_render_list) do
    spr(sprite.n, sprite.x, sprite.y, sprite.w, sprite.h, sprite.flip_x, sprite.flip_y)
  end
end

function handle_input()
  if btnp(3) then -- down (not something we actually expect to use; debugging only)
    add(players[1].hand, draw())
    players[1].hand = sort(players[1].hand, compare_cards)
  end

  if btnp(4) then -- z/action/square button
    selected_card = players[1].hand[leftmost + cursor - 1]
    if can_play(selected_card) then
      played_card = del(players[1].hand, selected_card)
      add(discard, played_card)

      if leftmost + cursor - 1 == #players[1].hand + 1 and cursor > 1 then
        cursor -= 1
      elseif leftmost == #players[1].hand + 1 then
        leftmost -= 1
      end

      if played_card.color == 4 then
        is_wild_selection_mode = true
      else
        resolve_card(played_card)
      end
    else
      -- play an ernnt sound
      sfx(0)
    end
  end

  if btnp(5) then -- x/secondary/x button
    if vulnerable_player > 1 then
      add(players[vulnerable_player].hand, draw())
      add(players[vulnerable_player].hand, draw())
      vulnerable_player = 0
      clear_ai_call_timers()
    else
      is_uno_called = true
      add_defensive_uno(1)
    end
  end

  if btnp(1) then -- right
    if cursor == 7 then
      if leftmost < #players[1].hand - 6 then leftmost += 1 end
    elseif leftmost + cursor - 1 < #players[1].hand then
      cursor += 1
    end
  end

  if btnp(0) then -- left
    if cursor == 1 then
      if leftmost > 1 then leftmost -= 1 end
    else
      cursor -= 1
    end
  end

  if btnp(2) then -- up
    is_on_deck = true
  end
end

function handle_deck_input()
  if btnp(3) then -- down
    is_on_deck = false
  end

  if btnp(4) then -- z/action/square button
    play_or_keep_card = draw()

    if can_play(play_or_keep_card) then
      is_play_or_keep_mode = true
      play_or_keep_cursor = 1 -- should always start on "play"
    else
      add(players[1].hand, play_or_keep_card)
      sort(players[1].hand, compare_cards)
      increment_player()
    end

    is_on_deck = false
  end
end

function handle_play_or_keep_mode_input()
  if btnp(2) or btnp(3) then -- up or down
    if play_or_keep_cursor == 2 then
      play_or_keep_cursor = 1
    else
      play_or_keep_cursor = 2
    end
  end

  if btnp(4) then -- z/action/square button
    if play_or_keep_cursor == 1 then -- play the card
      add(discard, play_or_keep_card)

      if play_or_keep_card.color == 4 then
        is_wild_selection_mode = true
      else
        resolve_card(play_or_keep_card)
      end
    else -- add it to hand
      add(players[1].hand, play_or_keep_card)
      sort(players[1].hand, compare_cards)
      increment_player()
    end

    is_play_or_keep_mode = false
    play_or_keep_cursor = 1
    play_or_keep_card = nil
  end

  if btnp(5) then -- x/secondary/x button
    if vulnerable_player > 1 then
      add(players[vulnerable_player].hand, draw())
      add(players[vulnerable_player].hand, draw())
      vulnerable_player = 0
      clear_ai_call_timers()
    else
      is_uno_called = true
      add_defensive_uno(1)
    end
  end
end

function handle_wild_selection_mode_input()
  if btnp(3) then -- down
    if wild_cursor == 4 then
      wild_cursor = 1
    else
      wild_cursor += 1
    end
  end

  if btnp(2) then -- up
    if wild_cursor == 1 then
      wild_cursor = 4
    else
      wild_cursor -= 1
    end
  end

  if btnp(4) then -- z/action/square button
    discard[#discard].color = wild_cursor - 1
    is_wild_selection_mode = false
    resolve_card(discard[#discard])
  end
end

function handle_game_over_mode_input()
  for i = 0, 5 do
    if btnp(i) then
      _init()
    end
  end
end

function generate_deck()
  deck = {}
  for color = 0, 3, 1 do
    for rank = 0, 12, 1 do
      local card = {}
      card.color = color
      card.rank = rank

      add(deck, card)
      if card.rank != 0 then
        add(deck, card)
      end
    end
  end

  for i = 0, 3 do
    add(deck, { color = 4, rank = 13})
    add(deck, { color = 4, rank = 14})
  end

  return deck
end

function shuffle(cards) -- fisher-yates, copied from https://gist.github.com/Uradamus/10323382
  for i = #cards, 2, -1 do
    local j = -flr(-rnd(i))
    cards[i], cards[j] = cards[j], cards[i]
  end
  return cards
end

function draw()
  if #deck == 0 then
    top = del(discard, discard[#discard])

    while #discard > 0 do
      current = del(discard, discard[#discard])
      if current.rank == 13 or current.rank == 14 then
        current.color = 4 -- reset wilds to wild (unselected) color
      end
      add(deck, current)
    end

    add(discard, top)
    deck = shuffle(deck)
  end

  -- @todo: do something smart here
  if #deck > 0 then
    sfx(2)
    return del(deck, deck[1])
  else
    return nil
  end
end

function print_deck()
  for index, card in pairs(deck) do
    print(get_display_rank(card.rank), flr((index - 1) / 10) * 10, ((index - 1) % 10) * 6, CARD_COLORS[card.color])
  end
end

function compare_cards(a, b)
  av = a.color * 25 + a.rank
  bv = b.color * 25 + b.rank

  return av - bv
end

function can_play(selected)
  local top_of_discard = discard[#discard]

  if selected.color == 4 then -- wild
    return true
  end

  if top_of_discard.color == 4 then -- if we haven't implemented wild color selection behavior yet...
    return true
  end

  if selected.color == top_of_discard.color or selected.rank == top_of_discard.rank then
    return true
  end

  return false
end

function draw_first_hand()
  local hand = {}
  for i = 1, 2 do
    add(hand, draw())
  end
  hand = sort(hand, compare_cards)
  return hand
end

function resolve_card(last_card)

  -- check game over status
  if #players[current_player].hand == 0 then
    is_game_over_mode = true
    return
  end

  -- handle uno status
  vulnerable_player = 0
  if #players[current_player].hand == 1 and is_uno_called then
    sfx(3) -- uno sfx
  elseif #players[current_player].hand == 1 and not is_uno_called then
    vulnerable_player = current_player
    start_ai_call_timers()
    sfx(1) -- play card sfx
  else
    sfx(1) -- hmmmmmm, this may be a problem later when it collides with the later sound effect
  end

  -- maybe a delay

  if last_card.rank == 10 then -- reverse
    turn_order *= -1
    if #players == 2 then increment_player() end
  elseif last_card.rank == 11 then -- skip
    increment_player()
  elseif last_card.rank == 12 then -- draw two
    increment_player()
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    sort(players[current_player].hand, compare_cards)
  elseif last_card.rank == 14 then -- wild draw four
    increment_player()
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    sort(players[current_player].hand, compare_cards)
  end

  increment_player()
end

function increment_player()
  current_player += turn_order

  if current_player > #players then
    current_player = 1
  elseif current_player < 1 then
    current_player = #players
  end

  is_uno_called = false
end

function get_player_display_color(player)
  if current_player == player then
    return players[player].color
  else
    return INACTIVE_PLAYER_COLOR
  end
end

function add_sprite_to_render_list(n, x, y, duration, w, h, flip_x, flip_y)
  if w == nil then w = 1 end
  if h == nil then h = 1 end
  if flip_x == nil then flip_x = false end
  if flip_y == nil then flip_y = false end

  local sprite = { n = n, x = x, y = y, duration = duration, w = w, h = h, flip_x = flip_x, flip_y = flip_y, timestamp = time() }
  add(sprite_render_list, sprite)
end

function clean_sprite_render_list()
  local to_clean = {}
  for sprite in all(sprite_render_list) do
    if sprite.timestamp + sprite.duration < time() then
      del(sprite_render_list, sprite)
    end
  end
end

function start_ai_call_timers()
  for i,player in pairs(players) do
    if i != 1 then -- if not human
      local timer = { timestamp = time(), reaction_time = rnd(player.max_reaction_time), player = i}
      add(ai_call_timers, timer)
      for k,v in pairs(timer) do
        printh(k..': '..tostr(v))
      end
    end
  end
end

function clear_ai_call_timers()
  ai_call_timers = {}
end

function handle_ai_call_timers()
  for timer in all(ai_call_timers) do
    if timer.timestamp + timer.reaction_time < time() then
      if vulnerable_player == timer.player then
        add_defensive_uno(timer.player)
      else
        add(players[vulnerable_player].hand, draw())
        add(players[vulnerable_player].hand, draw())
        add_offensive_uno(timer.player)
      end

      vulnerable_player = 0
      clear_ai_call_timers()
      break
    end
  end
end

-- AI LAND
function kaiba(player)
-- screw the rules, i've got money
  card = del(players[player].hand, players[player].hand[1])
  resolve_card(card)
  add(discard, card)
end

function joey(player)
  -- kinda dumb
  for card in all(shuffle(players[player].hand)) do
    if can_play(card) then
      card = del(players[player].hand, card)
      if card.color == 4 then -- if wild
        card.color = flr(rnd(4))
      end
      if #players[player].hand == 1 then
        if flr(rnd(2)) == 1 then -- coin flip
          is_uno_called = true
          add_defensive_uno(player)
        end
      end
      resolve_card(card)
      add(discard, card)
      return
    end
  end

  -- if we couldn't play anything...
  local card = add(players[player].hand, draw())
  if can_play(card) then
    card = del(players[player].hand, card)
    if card.color == 4 then -- if wild
      card.color = flr(rnd(4))
    end
    if #players[player].hand == 1 then
      if flr(rnd(2)) == 1 then -- coin flip
        is_uno_called = true
        add_defensive_uno(player)
      end
    end
    resolve_card(card)
    add(discard, card)
    return
  else
    increment_player()
  end
end

function mai(player)
  -- self-interested and lonely, I guess?
  -- anyways she's always going to play her highest-value card
  --   and she calls pretty aggressively, but forgets to be defensive
  local best_card = nil
  for card in all(players[player].hand) do
    if can_play(card) then
      if best_card == nil then
        best_card = card
      elseif card.rank > best_card.rank then
        best_card = card
      end
    end
  end

  if best_card == nil then
    local card = draw()
    if can_play(card) then
      if card.color == 4 then -- if wild
        card.color = get_mai_wild_color(players[player].hand)
      end
      resolve_card(card)
      add(discard, card)
      if #players[player].hand == 1 then
        if flr(rnd(3)) == 1 then -- sorta unlikely
          is_uno_called = true
          add_defensive_uno(player)
        end
      end
    else
      add(players[player].hand, card)
      increment_player()
    end
  else
    del(players[player].hand, best_card)
    if best_card.color == 4 then -- if wild
      best_card.color = get_mai_wild_color(players[player].hand)
    end
    resolve_card(best_card)
    add(discard, best_card)
    if #players[player].hand == 1 then
      if flr(rnd(3)) == 1 then -- sorta unlikely
        is_uno_called = true
        add_defensive_uno(player)
      end
    end
  end
end

function get_mai_wild_color(hand)
  -- make sure the wild isn't still in her hand before
  -- doing this...
  local highest_value_card = nil -- find the highest value card's color, and choose that
  for card in all(hand) do
    if highest_value_card == nil then
      highest_value_card = card
    elseif highest_value_card.rank < card.rank then
      highest_value_card = card
    end
  end

  if highest_value_card.color == 4 then -- if it's a wild, then she'll play it next turn anyways, so who cares
    return flr(rnd(4))
  else
    return highest_value_card.color
  end
end

function solomon(player)
  -- GRANDPA
  -- always tries to keep a balance between all of the colors in his hand
  -- saves wilds until last
  -- calls less often, but defensively calls most of the time

  -- @todo: consider bailing and just playing any valid card if we can't
  -- play a card in the most common color
  -- @todo: deprioritize wilds

  local color_counts = {
    { name='red', count=0 },
    { name='green', count=0 },
    { name='blue', count=0 },
    { name='yellow', count=0 },
    { name='wild', count=0 }
  }
  local playable_cards = {}
  for card in all(players[player].hand) do
    if can_play(card) then add(playable_cards, card) end
    color_counts[card.color].count += 1
  end

  local best_card = nil
  for color in sort(color_counts, compare_color_counts) do
    local color_index = get_color_index_by_name(color.name)
    for card in filter_by_color(playable_cards, color_index) do
      if best_card == nil then
        best_card = card
      elseif card.rank > best_card.rank then
        best_card = card
      end
    end
  end

  if best_card == nil then
    local card = draw()
    if can_play(card) then
      if card.color == 4 then -- if wild
        card.color = sort(color_counts, compare_color_counts)[1]
      end
      resolve_card(card)
      add(discard, card)
      if #players[player].hand == 1 then
        if flr(rnd(3)) > 0 then -- pretty likely
          is_uno_called = true
          add_defensive_uno(player)
        end
      end
    else
      add(players[player].hand, card)
      increment_player()
    end
  else
    del(players[player].hand, best_card)
    if best_card.color == 4 then -- if wild
      best_card.color = sort(color_counts, compare_color_counts)[1]
    end
    resolve_card(best_card)
    add(discard, best_card)
    if #players[player].hand == 1 then
      if flr(rnd(3)) > 0 then -- pretty likely
        is_uno_called = true
        add_defensive_uno(player)
      end
    end
  end
end

function compare_color_counts(a, b)
  return a.count - b.count
end

function get_color_index_by_name(name)
  if name == 'red' then
    return 0
  elseif name == 'green' then
    return 1
  elseif name == 'blue' then
    return 2
  elseif name == 'yellow' then
    return 3
  elseif name =='wild' then
    return 4
  end
end

function filter_by_color(cards, color)
  local filtered = {}

  for card in cards do
    if card.color == color then
      add(filtered, card)
    end
  end

  return filtered
end

-- LIBRARY FUNCTIONS
function ceil(x)
  return -flr(-x)
end

function subseq(seq, from, to)
  new_seq = {}

  if to == nil then
    to = #seq
  end

  for k,v in pairs(seq) do
    if k > to then break end
    if k >= from then
      add(new_seq, v)
    end
  end

  return new_seq
end

function sort(seq, comparator) -- bubble sort
  repeat
    local done = true
    for i = 1, #seq - 1 do
      if comparator(seq[i], seq[i+1]) > 0 then
        seq[i], seq[i+1] = seq[i+1], seq[i]
        done = false
      end
    end
  until done

  return seq
end

function get_center_text_positions(text, x, y)
  x = x or 0
  y = y or 0
  local text_width = 3 + 1
  local text_height = 5
  return { x = x - (#text * text_width / 2) + 1, y = y - (text_height / 2) }
end


__gfx__
00000000070000000000000077770000077777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000777770007770000700000000000000708080bb00ccc0a000000000000000000000000000000000000000000000000000000000000000000
00700700077700000777770000000000700000000000000708080b0b0c0c0a000000000000000000000000000000000000000000000000000000000000000000
00077000077770000777770000000000700000000000000708080b0b0c0c00000000000000000000000000000000000000000000000000000000000000000000
00077000077700000077700000000000700000000000000708880b0b0ccc0a000000000000000000000000000000000000000000000000000000000000000000
00700700077000000007000000000000070077777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000700770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000700000007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000700000070007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000007070000070007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77000070007000700000700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777700000777700000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070008080bb00ccc0a0070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007008080b0b0c0c0a0070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000708080b0b0c0c000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000708880b0b0ccc0a0070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000000777000007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00707770007000700070000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770007070000070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000007070000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000007450074500745000000000000000000000074500745007450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001c6101e150211501f10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001a6101e600226102961000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000000000000002d0302d0502f0502f0502d0502d0502d0502a00026050260502605026050260502604026040260302603026020265002650025500000000000000000000000000000000000000000000000
